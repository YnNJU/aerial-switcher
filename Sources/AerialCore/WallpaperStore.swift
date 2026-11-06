import Foundation

public enum WallpaperState: Hashable, Sendable {
    case aerial(assetID: String)
    /// The macOS default wallpaper. It is itself an Aerial, but stored without an asset ID.
    case systemDefault
    /// A picture, color, or anything else.
    case other
}

/// Reads and rewrites macOS's wallpaper store (Index.plist).
///
/// The store holds scopes (all displays, per display, per space), each with entries
/// (Linked, Desktop, Idle, ScreenSaver) whose Choices name a provider and its configuration.
/// An Aerial choice is provider `com.apple.wallpaper.choice.aerials` with `{assetID}` as config.
public struct WallpaperStore: Sendable {
    static let aerialProvider = "com.apple.wallpaper.choice.aerials"
    static let desktopEntries = ["Linked", "Desktop"]
    static let screenSaverEntries = ["Idle", "ScreenSaver"]

    let paths: Paths

    public init(paths: Paths = .live) {
        self.paths = paths
    }

    /// What every desktop shows. Scopes that disagree, as when one display was set on its
    /// own in System Settings, count as `.other`: the system default scope alone can name
    /// an Aerial that no display shows.
    public func state() throws -> WallpaperState {
        let states = Set(desktopChoices(in: try load()).map { choice -> WallpaperState in
            if let assetID = Self.assetID(of: choice) { return .aerial(assetID: assetID) }
            return choice["Provider"] as? String == "default" ? .systemDefault : .other
        })
        return states.count == 1 ? states.first! : .other
    }

    /// Shows `assetID` on every display and space. Desktop entries that aren't an Aerial are
    /// replaced; screen saver entries are only updated if they already show an Aerial.
    /// The user's own wallpaper is kept so it can be restored: the store as it was before
    /// the first change, refreshed whenever the user has picked something else since.
    @discardableResult
    public func setAerial(_ assetID: String, now: Date = Date()) throws -> Int {
        let store = try load()
        let config = try PropertyListSerialization.data(fromPropertyList: ["assetID": assetID], format: .binary, options: 0)
        var count = 0

        for scope in scopes(in: store) {
            for key in Self.desktopEntries + Self.screenSaverEntries {
                guard
                    let entry = scope[key] as? NSMutableDictionary,
                    let content = entry["Content"] as? NSMutableDictionary,
                    let choices = content["Choices"] as? NSMutableArray
                else { continue }

                var changed = false
                for case let choice as NSMutableDictionary in choices where choice["Provider"] as? String == Self.aerialProvider {
                    choice["Configuration"] = try Self.configuration(of: choice, settingAssetID: assetID)
                    changed = true
                }
                if !changed && Self.desktopEntries.contains(key) {
                    content["Choices"] = NSMutableArray(object: NSMutableDictionary(dictionary: [
                        "Provider": Self.aerialProvider,
                        "Configuration": config,
                        "Files": NSMutableArray(),
                    ]))
                    content["Shuffle"] = "$null"
                    changed = true
                }
                if changed {
                    entry["LastSet"] = now
                    entry["LastUse"] = now
                    count += 1
                }
            }
        }

        guard count > 0 else { throw AerialError("No wallpaper entries were found in the wallpaper store.") }
        try backUpUsersWallpaper()
        let data = try PropertyListSerialization.data(fromPropertyList: store, format: .binary, options: 0)
        try data.write(to: paths.store, options: .atomic)
        try Data(assetID.utf8).write(to: paths.lastSet, options: .atomic)
        return count
    }

    public var hasBackup: Bool { FileManager.default.fileExists(atPath: paths.storeBackup.path) }

    /// Whether the wallpaper showing is the one this app last set, not one the user picked since.
    public var isShowingOwnChange: Bool {
        guard let data = try? Data(contentsOf: paths.lastSet) else {
            // 1.0.0 kept a backup but didn't record its change; any Aerial counts as its own.
            guard hasBackup, case .aerial = try? state() else { return false }
            return true
        }
        return (try? state()) == .aerial(assetID: String(decoding: data, as: UTF8.self))
    }

    /// Puts back the user's wallpaper, unless they have already picked another one since
    /// this app's last change. Returns whether the store was changed.
    @discardableResult
    public func restoreBackup() throws -> Bool {
        let restore = hasBackup && isShowingOwnChange
        if restore {
            try Data(contentsOf: paths.storeBackup).write(to: paths.store, options: .atomic)
        }
        try? FileManager.default.removeItem(at: paths.storeBackup)
        try? FileManager.default.removeItem(at: paths.lastSet)
        return restore
    }

    /// WallpaperAgent only picks up store changes when it restarts.
    public static func reloadAgent() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["WallpaperAgent"]
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Helpers

    private func load() throws -> NSMutableDictionary {
        guard
            let data = try? Data(contentsOf: paths.store),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil),
            let store = plist as? NSMutableDictionary
        else {
            throw AerialError("Couldn't read the wallpaper store.")
        }
        return store
    }

    private func backUpUsersWallpaper() throws {
        guard !(hasBackup && isShowingOwnChange) else { return }
        try FileManager.default.createDirectory(at: paths.appSupport, withIntermediateDirectories: true)
        try Data(contentsOf: paths.store).write(to: paths.storeBackup, options: .atomic)
    }

    /// Every dictionary holding entries. Per-display and per-space scopes nest: with
    /// "Show on all Spaces" off, a space keeps its own `Default` and `Displays.<display>`.
    private func scopes(in store: NSDictionary) -> [NSMutableDictionary] {
        let entryKeys = Self.desktopEntries + Self.screenSaverEntries
        func collect(_ value: Any) -> [NSMutableDictionary] {
            guard let dictionary = value as? NSMutableDictionary else { return [] }
            if entryKeys.contains(where: { dictionary[$0] != nil }) { return [dictionary] }
            return dictionary.allValues.flatMap(collect)
        }
        return ["AllSpacesAndDisplays", "SystemDefault", "Displays", "Spaces"].flatMap { store[$0].map(collect) ?? [] }
    }

    private func desktopChoices(in store: NSDictionary) -> [NSDictionary] {
        scopes(in: store).flatMap { scope in
            Self.desktopEntries.flatMap { key -> [NSDictionary] in
                let content = (scope[key] as? NSDictionary)?["Content"] as? NSDictionary
                return (content?["Choices"] as? [NSDictionary]) ?? []
            }
        }
    }

    private static func assetID(of choice: NSDictionary) -> String? {
        guard
            choice["Provider"] as? String == aerialProvider,
            let data = choice["Configuration"] as? Data,
            let config = try? PropertyListSerialization.propertyList(from: data, format: nil) as? NSDictionary
        else { return nil }
        return config["assetID"] as? String
    }

    /// Keeps any other keys an existing Aerial configuration has.
    private static func configuration(of choice: NSDictionary, settingAssetID assetID: String) throws -> Data {
        let existing = (choice["Configuration"] as? Data).flatMap {
            try? PropertyListSerialization.propertyList(from: $0, format: nil) as? NSDictionary
        }
        let config = NSMutableDictionary(dictionary: existing ?? [:])
        config["assetID"] = assetID
        return try PropertyListSerialization.data(fromPropertyList: config, format: .binary, options: 0)
    }
}

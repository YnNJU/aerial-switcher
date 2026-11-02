import Foundation

public enum WallpaperState: Equatable, Sendable {
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

    public func state() throws -> WallpaperState {
        var sawDefault = false
        for choice in desktopChoices(in: try load()) {
            if let assetID = Self.assetID(of: choice) { return .aerial(assetID: assetID) }
            if choice["Provider"] as? String == "default" { sawDefault = true }
        }
        return sawDefault ? .systemDefault : .other
    }

    /// Shows `assetID` on every display and space. Desktop entries that aren't an Aerial are
    /// replaced; screen saver entries are only updated if they already show an Aerial.
    /// The store as it was before the first change is kept so it can be restored.
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
        try backupIfNeeded()
        let data = try PropertyListSerialization.data(fromPropertyList: store, format: .binary, options: 0)
        try data.write(to: paths.store, options: .atomic)
        return count
    }

    public var hasBackup: Bool { FileManager.default.fileExists(atPath: paths.storeBackup.path) }

    /// Puts back the wallpaper the user had before this app first changed it.
    public func restoreBackup() throws {
        let data = try Data(contentsOf: paths.storeBackup)
        try data.write(to: paths.store, options: .atomic)
        try FileManager.default.removeItem(at: paths.storeBackup)
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

    private func backupIfNeeded() throws {
        guard !hasBackup else { return }
        try FileManager.default.createDirectory(at: paths.appSupport, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: paths.store, to: paths.storeBackup)
    }

    private func scopes(in store: NSDictionary) -> [NSMutableDictionary] {
        var scopes = ["AllSpacesAndDisplays", "SystemDefault"].compactMap { store[$0] as? NSMutableDictionary }
        for key in ["Displays", "Spaces"] {
            if let container = store[key] as? NSDictionary {
                scopes += container.allValues.compactMap { $0 as? NSMutableDictionary }
            }
        }
        return scopes
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

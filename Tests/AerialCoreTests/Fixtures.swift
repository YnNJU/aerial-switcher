import Foundation
@testable import AerialCore

enum Fixtures {
    static func asset(_ id: String, _ label: String, _ subcategory: String) -> [String: Any] {
        ["id": id, "accessibilityLabel": label, "localizedNameKey": "\(id)_NAME", "subcategories": [subcategory], "url-4K-SDR-240FPS": "https://example.com/\(id).mov"]
    }

    /// Mirrors the real manifest: Tahoe and Golden Gate are day cycles (listed out of order),
    /// Sonoma is a set of places, and the macOS default has a one-word label. Golden Gate Day
    /// has a raw shot name as its label; its real name is only in the strings table.
    static let manifest: Data = try! JSONSerialization.data(withJSONObject: [
        "assets": [
            asset("GG-NIGHT", "Golden Gate Night", "gg"),
            asset("TA-DAY", "Tahoe Day", "tahoe"),
            asset("TA-MORNING", "Tahoe Morning", "tahoe"),
            asset("TA-EVENING", "Tahoe Evening", "tahoe"),
            asset("TA-NIGHT", "Tahoe Night", "tahoe"),
            asset("GG-SUNSET", "Golden Gate Sunset", "gg"),
            asset("GG-DAY", "GG_A_DAY_BLUFFS_C35_V25_HFR_HEVC", "gg"),
            asset("SO-EVENING", "Sonoma Evening", "sonoma"),
            asset("SO-CLOUDS", "Sonoma Clouds", "sonoma"),
            asset("MAC", "macOS", "dynamic"),
            asset("LONE", "Lone Night", "lone"),
        ],
        "categories": [["subcategories": [["id": "gg", "localizedNameKey": "SubcategoryGoldenGate"]]]],
    ])

    static let strings = Strings([
        "en": ["GG-DAY_NAME": "Golden Gate Day", "SubcategoryGoldenGate": "Golden Gate"],
        "zh_CN": ["GG-DAY_NAME": "金门海峡白天", "SubcategoryGoldenGate": "金门海峡"],
    ], preferredLanguages: ["en"])

    static var sets: [AerialSet] { try! Manifest.sets(from: manifest, strings: strings) }
    static var tahoe: AerialSet { sets.first { $0.id == "tahoe" }! }

    static func choice(provider: String, config: [String: Any]?) -> [String: Any] {
        let data = config.map { try! PropertyListSerialization.data(fromPropertyList: $0, format: .binary, options: 0) } ?? Data()
        return ["Provider": provider, "Configuration": data, "Files": [Any]()]
    }

    static var aerialChoice: [String: Any] { choice(provider: "com.apple.wallpaper.choice.aerials", config: ["assetID": "OLD"]) }
    static var imageChoice: [String: Any] { choice(provider: "com.apple.wallpaper.choice.image", config: ["type": "imageFile"]) }
    static var defaultChoice: [String: Any] { choice(provider: "default", config: nil) }

    static func store(_ choice: [String: Any]) -> [String: Any] {
        let scope: [String: Any] = [
            "Linked": ["Content": ["Choices": [choice], "Shuffle": "$null"], "LastSet": Date(timeIntervalSince1970: 0)],
            "Type": "linked",
        ]
        return ["AllSpacesAndDisplays": scope, "SystemDefault": scope, "Displays": [String: Any](), "Spaces": [String: Any]()]
    }

    /// A throwaway home folder with a wallpaper store in it.
    static func paths(store: [String: Any]) throws -> Paths {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let paths = Paths(home: home)
        try FileManager.default.createDirectory(at: paths.store.deletingLastPathComponent(), withIntermediateDirectories: true)
        try write(store, to: paths)
        return paths
    }

    /// Replaces the store, as when the user picks a wallpaper in System Settings.
    static func write(_ store: [String: Any], to paths: Paths) throws {
        try PropertyListSerialization.data(fromPropertyList: store, format: .binary, options: 0).write(to: paths.store)
    }

    static func download(_ ids: [String], into paths: Paths) throws {
        try FileManager.default.createDirectory(at: paths.videos, withIntermediateDirectories: true)
        for id in ids {
            try Data([1]).write(to: paths.videos.appendingPathComponent("\(id).mov"))
        }
    }

    static func date(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: hour, minute: minute))!
    }

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()
}

import Foundation

/// A time of day an Aerial was shot at, parsed from the last word of its label
/// ("Tahoe Morning" → .morning). Declared in the order the phases occur in a day.
public enum DayPhase: String, CaseIterable, Codable, CodingKeyRepresentable, Comparable, Sendable {
    case sunrise, morning, day, sunset, evening, night

    public static func < (lhs: DayPhase, rhs: DayPhase) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }

    /// Suggested start time when the user hasn't picked one.
    var suggestedStart: TimeOfDay {
        switch self {
        case .sunrise: TimeOfDay(hour: 6)
        case .morning: TimeOfDay(hour: 8)
        case .day: TimeOfDay(hour: 12)
        case .sunset: TimeOfDay(hour: 17)
        case .evening: TimeOfDay(hour: 18)
        case .night: TimeOfDay(hour: 21)
        }
    }

    public var title: String { rawValue.capitalized }
}

public struct Aerial: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let phase: DayPhase
    public let videoURL: URL?
}

/// A group of Aerials of one place shot at different times of day, e.g. Tahoe.
public struct AerialSet: Identifiable, Hashable, Sendable {
    /// The manifest subcategory ID.
    public let id: String
    public let name: String
    /// Sorted by phase.
    public let aerials: [Aerial]

    public func aerial(for phase: DayPhase) -> Aerial? {
        aerials.first { $0.phase == phase }
    }

    /// Default schedule: suggested times, with the earliest phase moved to 06:00 so a set
    /// without a sunrise/morning shot doesn't keep showing night until noon.
    public var defaultSchedule: Schedule {
        let times = Dictionary(uniqueKeysWithValues: aerials.enumerated().map { index, aerial in
            (aerial.phase, index == 0 ? TimeOfDay(hour: 6) : aerial.phase.suggestedStart)
        })
        return Schedule(times)
    }
}

public enum Manifest {
    /// Names are in the first of `preferredLanguages` that macOS has them in.
    public static func load(from url: URL, preferredLanguages: [String] = Locale.preferredLanguages) throws -> [AerialSet] {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw AerialError("Couldn't read the Aerial manifest. Open System Settings › Wallpaper once so macOS downloads it.")
        }
        return try sets(from: data, strings: Strings(contentsOf: url.deletingLastPathComponent()
            .appendingPathComponent("TVIdleScreenStrings.bundle/Contents/Resources/Localizable.nocache.loctable"), preferredLanguages: preferredLanguages))
    }

    /// Finds the day-cycle sets: subcategories with at least two Aerials whose English names
    /// share a place name and each end in a different time of day. Sets like Sonoma
    /// (Clouds, River…) are ignored.
    public static func sets(from data: Data, strings: Strings = Strings()) throws -> [AerialSet] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let assets = json["assets"] as? [[String: Any]]
        else {
            throw AerialError("The Aerial manifest has an unexpected format.")
        }

        // Subcategory ID → name key, e.g. "AerialSubcategoryTahoe".
        var subcategoryKeys: [String: String] = [:]
        for category in json["categories"] as? [[String: Any]] ?? [] {
            for subcategory in category["subcategories"] as? [[String: Any]] ?? [] {
                if let id = subcategory["id"] as? String, let key = subcategory["localizedNameKey"] as? String {
                    subcategoryKeys[id] = key
                }
            }
        }

        var groups: [String: [(place: String, aerial: Aerial)]] = [:]
        var order: [String] = []
        var rejected: Set<String> = []

        for asset in assets {
            guard let id = asset["id"] as? String, let subcategory = (asset["subcategories"] as? [String])?.first else { continue }
            // accessibilityLabel is sometimes a raw shot name ("GG_A_DAY_BLUFFS_…"); the
            // strings table has the name System Settings shows.
            let key = asset["localizedNameKey"] as? String
            guard let english = key.flatMap(strings.english) ?? asset["accessibilityLabel"] as? String else { continue }

            var words = english.split(separator: " ")
            guard words.count > 1, let phase = DayPhase(rawValue: words.removeLast().lowercased()) else {
                rejected.insert(subcategory)
                continue
            }
            let url = (asset["url-4K-SDR-240FPS"] as? String).flatMap(URL.init(string:))
            let label = key.flatMap(strings.localized) ?? english
            if groups[subcategory] == nil { order.append(subcategory) }
            groups[subcategory, default: []].append((words.joined(separator: " "), Aerial(id: id, label: label, phase: phase, videoURL: url)))
        }

        return order.compactMap { subcategory in
            guard !rejected.contains(subcategory), let members = groups[subcategory], members.count > 1 else { return nil }
            let places = Set(members.map(\.place))
            let phases = members.map(\.aerial.phase)
            guard places.count == 1, Set(phases).count == phases.count else { return nil }
            let sorted = members.map(\.aerial).sorted { $0.phase < $1.phase }
            let name = subcategoryKeys[subcategory].flatMap(strings.localized) ?? members[0].place
            return AerialSet(id: subcategory, name: name, aerials: sorted)
        }
    }
}

/// The Aerial names macOS shows, from the strings table that ships next to the manifest:
/// a plist of `[localization: [key: name]]`.
public struct Strings: Sendable {
    let tables: [String: [String: String]]
    let preferred: String?

    public init(_ tables: [String: [String: String]] = [:], preferredLanguages: [String] = Locale.preferredLanguages) {
        self.tables = tables
        preferred = Bundle.preferredLocalizations(from: Array(tables.keys), forPreferences: preferredLanguages).first
    }

    init(contentsOf url: URL, preferredLanguages: [String]) {
        let plist = (try? Data(contentsOf: url)).flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) }
        // Tables can hold non-string entries (plural rules, metadata); keep only the names.
        let tables = (plist as? [String: Any] ?? [:]).compactMapValues { table in
            (table as? [String: Any])?.compactMapValues { $0 as? String }
        }
        self.init(tables, preferredLanguages: preferredLanguages)
    }

    func english(_ key: String) -> String? { tables["en"]?[key] }
    func localized(_ key: String) -> String? { preferred.flatMap { tables[$0]?[key] } ?? english(key) }
}

import Foundation

/// What the user picked, saved as JSON in the app's Application Support folder.
public struct Config: Codable, Equatable, Sendable {
    /// ID of the chosen set; nil until the user picks one.
    public var setID: String?
    /// Custom times per set, so switching sets back and forth keeps each set's edits.
    public var schedules: [String: Schedule] = [:]
    /// Off: no switching, and the wallpaper from before the app is put back.
    public var enabled = true
    /// Paused: no switching, the wallpaper showing stays.
    public var paused = false

    public init(setID: String? = nil, schedules: [String: Schedule] = [:], enabled: Bool = true, paused: Bool = false) {
        self.setID = setID
        self.schedules = schedules
        self.enabled = enabled
        self.paused = paused
    }

    /// Settings saved by an older version may lack newer keys; those get their defaults.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        setID = try container.decodeIfPresent(String.self, forKey: .setID)
        schedules = try container.decodeIfPresent([String: Schedule].self, forKey: .schedules) ?? [:]
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        paused = try container.decodeIfPresent(Bool.self, forKey: .paused) ?? false
    }

    public func schedule(for set: AerialSet) -> Schedule {
        schedules[set.id] ?? set.defaultSchedule
    }

    public static func load(from url: URL) -> Config {
        guard let data = try? Data(contentsOf: url) else { return Config() }
        return (try? JSONDecoder().decode(Config.self, from: data)) ?? Config()
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}

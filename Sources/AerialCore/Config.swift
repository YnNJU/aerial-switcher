import Foundation

/// What the user picked, saved as JSON in the app's Application Support folder.
public struct Config: Codable, Equatable, Sendable {
    /// ID of the chosen set; nil until the user picks one.
    public var setID: String?
    /// Custom times per set, so switching sets back and forth keeps each set's edits.
    public var schedules: [String: Schedule] = [:]
    public var paused = false

    public init(setID: String? = nil, schedules: [String: Schedule] = [:], paused: Bool = false) {
        self.setID = setID
        self.schedules = schedules
        self.paused = paused
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

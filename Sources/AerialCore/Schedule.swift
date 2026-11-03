import Foundation

public struct TimeOfDay: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    /// Minutes since midnight, 0..<1440.
    public let minutes: Int

    public init(hour: Int, minute: Int = 0) {
        minutes = (hour * 60 + minute).clamped(to: 0...1439)
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    public var hour: Int { minutes / 60 }
    public var minute: Int { minutes % 60 }
    public var description: String { String(format: "%02d:%02d", hour, minute) }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool { lhs.minutes < rhs.minutes }

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Expected HH:mm, got \(text)"))
        }
        self.init(hour: parts[0], minute: parts[1])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

/// When each phase of a set starts. The schedule wraps around midnight: the last phase of the
/// day stays on until the first one starts again.
public struct Schedule: Codable, Equatable, Sendable {
    public var times: [DayPhase: TimeOfDay]

    public init(_ times: [DayPhase: TimeOfDay]) {
        self.times = times
    }

    /// Phases ordered by start time; ties keep day order and the later phase wins.
    public var entries: [(phase: DayPhase, start: TimeOfDay)] {
        times.map { ($0.key, $0.value) }.sorted { ($0.start, $0.phase) < ($1.start, $1.phase) }
    }

    public func phase(at date: Date, calendar: Calendar = .current) -> DayPhase? {
        let now = TimeOfDay(date, calendar: calendar)
        let entries = entries
        return (entries.last { $0.start <= now } ?? entries.last)?.phase
    }

    /// The next moment the shown phase changes, and the phase it changes to.
    public func nextChange(after date: Date, calendar: Calendar = .current) -> (date: Date, phase: DayPhase)? {
        let current = phase(at: date, calendar: calendar)
        let candidates = entries.compactMap { entry -> (date: Date, phase: DayPhase)? in
            guard
                let next = calendar.nextDate(
                    after: date,
                    matching: DateComponents(hour: entry.start.hour, minute: entry.start.minute),
                    matchingPolicy: .nextTime
                ),
                let shown = phase(at: next, calendar: calendar),
                shown != current
            else { return nil }
            return (next, shown)
        }
        return candidates.min { $0.date < $1.date }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}

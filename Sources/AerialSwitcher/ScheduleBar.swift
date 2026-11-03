import AerialCore
import SwiftUI

/// The day as a 24-hour bar, one colored stretch per phase. Dragging the handle at the
/// start of a phase moves its start time, in 15-minute steps, between its neighbors.
struct ScheduleBar: View {
    let schedule: Schedule
    /// The phase showing now, marked in the legend.
    let current: DayPhase?
    /// A new start time; `commit` is false while the handle is still being dragged.
    let onChange: (DayPhase, TimeOfDay, _ commit: Bool) -> Void

    private let trackHeight: CGFloat = 28
    private let step = 15

    var body: some View {
        let entries = schedule.entries
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    track(entries, width: width)
                    ForEach(Array(entries.enumerated()), id: \.element.phase) { index, entry in
                        handle(for: entry.phase, at: index, in: entries, width: width)
                    }
                }
                .coordinateSpace(name: "bar")
            }
            .frame(height: trackHeight + 8)

            HStack {
                ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                    if hour > 0 { Spacer() }
                    Text(String(format: "%02d:00", hour))
                }
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), alignment: .leading, spacing: 8) {
                ForEach(entries, id: \.phase) { entry in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(entry.phase.color)
                            .frame(width: 10, height: 10)
                        Text(entry.phase.title)
                            .fontWeight(entry.phase == current ? .semibold : .regular)
                        Text(entry.start.description)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private func track(_ entries: [(phase: DayPhase, start: TimeOfDay)], width: CGFloat) -> some View {
        // Each phase runs until the next one starts; the last runs on past midnight,
        // so it also fills the stretch before the first.
        var spans: [(phase: DayPhase, from: Int, to: Int)] = []
        if let first = entries.first, let last = entries.last, first.start.minutes > 0 {
            spans.append((last.phase, 0, first.start.minutes))
        }
        for (index, entry) in entries.enumerated() {
            let end = index + 1 < entries.count ? entries[index + 1].start.minutes : 1440
            spans.append((entry.phase, entry.start.minutes, end))
        }
        return ZStack(alignment: .leading) {
            ForEach(Array(spans.enumerated()), id: \.offset) { _, span in
                let spanWidth = CGFloat(span.to - span.from) / 1440 * width
                Rectangle()
                    .fill(span.phase.color)
                    .frame(width: spanWidth, height: trackHeight)
                    .overlay {
                        if spanWidth > 26 {
                            Image(systemName: span.phase.symbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .offset(x: CGFloat(span.from) / 1440 * width)
            }
        }
        .frame(width: width, height: trackHeight, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func handle(for phase: DayPhase, at index: Int, in entries: [(phase: DayPhase, start: TimeOfDay)], width: CGFloat) -> some View {
        // Stay between the neighbors, so dragging never reorders the day.
        let lower = index > 0 ? entries[index - 1].start.minutes + step : 0
        let upper = index + 1 < entries.count ? entries[index + 1].start.minutes - step : 1440 - step
        let x = CGFloat(entries[index].start.minutes) / 1440 * width

        func time(at location: CGFloat) -> TimeOfDay {
            let minutes = Int((location / width * 1440 / CGFloat(step)).rounded()) * step
            return TimeOfDay(hour: 0, minute: min(max(minutes, lower), upper))
        }

        return Capsule()
            .fill(.white)
            .frame(width: 6, height: trackHeight + 8)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            .frame(width: 20, height: trackHeight + 8)
            .contentShape(Rectangle())
            .offset(x: x - 10)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("bar"))
                    .onChanged { onChange(phase, time(at: $0.location.x), false) }
                    .onEnded { onChange(phase, time(at: $0.location.x), true) }
            )
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .help("\(phase.title) starts at \(entries[index].start)")
    }
}

extension DayPhase {
    var color: Color {
        switch self {
        case .sunrise: Color(red: 0.98, green: 0.69, blue: 0.47)
        case .morning: Color(red: 0.96, green: 0.79, blue: 0.42)
        case .day: Color(red: 0.36, green: 0.67, blue: 0.95)
        case .sunset: Color(red: 0.95, green: 0.50, blue: 0.33)
        case .evening: Color(red: 0.52, green: 0.40, blue: 0.75)
        case .night: Color(red: 0.17, green: 0.21, blue: 0.45)
        }
    }
}

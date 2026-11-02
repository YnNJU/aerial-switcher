import AerialCore
import SwiftUI

struct MenuContent: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(statusLines, id: \.self) { Text($0) }
        Divider()
        Button(model.config.paused ? "Resume" : "Pause") { model.togglePause() }
            .disabled(model.selectedSet == nil)
        Button("Settings…") {
            NSApp.activate()
            openWindow(id: "settings")
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Aerial Switcher") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var statusLines: [String] {
        guard let set = model.selectedSet else { return [model.error ?? "Choose a set in Settings"] }
        var lines = [[set.name, model.currentPhase?.title].compactMap { $0 }.joined(separator: " · ")]

        if let error = model.error {
            lines.append("⚠︎ \(error)")
        } else if let download = model.download {
            lines.append("Downloading \(download.index + 1) of \(download.count) · \(Int(download.fraction * 100))%")
        } else if model.config.paused {
            lines.append("Paused")
        } else if let next = model.nextChange {
            lines.append("\(next.phase.title) at \(next.date.formatted(date: .omitted, time: .shortened))")
        }
        return lines
    }
}

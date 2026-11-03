import AerialCore
import SwiftUI

struct MenuContent: View {
    let model: AppModel

    var body: some View {
        ForEach(statusLines, id: \.self) { Text($0) }
        Divider()
        Toggle("Switch Wallpaper", isOn: Binding(get: { model.config.enabled }, set: { model.setEnabled($0) }))
            .disabled(model.selectedSet == nil)
        Toggle("Pause", isOn: Binding(get: { model.config.paused }, set: { model.setPaused($0) }))
            .disabled(model.selectedSet == nil || !model.config.enabled)
        Divider()
        Picker("Set", selection: Binding(
            get: { model.config.setID ?? "" },
            set: { model.selectSet($0) }
        )) {
            ForEach(model.sets) { Text($0.name).tag($0.id) }
        }
        .pickerStyle(.inline)
        Divider()
        Button("Settings…") {
            NotificationCenter.default.post(name: .showSettings, object: nil)
        }
        .keyboardShortcut(",")
        Button("Quit Aerial Switcher") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var statusLines: [String] {
        guard let set = model.selectedSet else { return [model.error ?? "Choose a set below"] }
        var lines = [[set.name, model.config.enabled ? model.currentPhase?.title : nil].compactMap { $0 }.joined(separator: " · ")]

        if let error = model.error {
            lines.append("⚠︎ \(error)")
        } else if let download = model.download {
            lines.append("Downloading \(download.index + 1) of \(download.count) · \(Int(download.fraction * 100))%")
        } else if !model.config.enabled {
            lines.append("Off · original wallpaper")
        } else if model.config.paused {
            lines.append("Paused")
        } else if let next = model.nextChange {
            lines.append("\(next.phase.title) at \(next.date.formatted(date: .omitted, time: .shortened))")
        }
        return lines
    }
}

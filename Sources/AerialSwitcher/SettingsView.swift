import AerialCore
import SwiftUI

/// Placeholder layout: plain native form until the design is settled.
struct SettingsView: View {
    let model: AppModel

    var body: some View {
        Form {
            Section {
                Picker("Set", selection: Binding(
                    get: { model.config.setID ?? "" },
                    set: { model.selectSet($0) }
                )) {
                    if model.config.setID == nil { Text("Choose…").tag("") }
                    ForEach(model.sets) { Text($0.name).tag($0.id) }
                }
                if let download = model.download {
                    ProgressView(value: (Double(download.index) + download.fraction) / Double(download.count)) {
                        Text(downloadTitle(download))
                    }
                }
            } footer: {
                Text("Aerials of one place, shot at different times of day. Videos that aren't on this Mac yet are downloaded from Apple.")
            }

            if let set = model.selectedSet, let schedule = model.schedule {
                Section {
                    ForEach(set.aerials) { aerial in
                        DatePicker(aerial.phase.title, selection: time(for: aerial.phase, in: schedule), displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Schedule")
                } footer: {
                    HStack {
                        Spacer()
                        Button("Reset to Defaults") { model.resetSchedule() }
                            .disabled(model.config.schedules[set.id] == nil)
                    }
                }
            }

            Section {
                Toggle("Launch at Login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                if model.hasBackup {
                    LabeledContent("Original Wallpaper") {
                        Button("Restore") { model.restoreOriginalWallpaper() }
                    }
                }
            }

            if let error = model.error {
                Text(error).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func downloadTitle(_ download: AppModel.Download) -> String {
        let size = download.totalBytes.map { " · " + ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? ""
        return "Downloading \(download.index + 1) of \(download.count)\(size)"
    }

    private func time(for phase: DayPhase, in schedule: Schedule) -> Binding<Date> {
        Binding(
            get: {
                let time = schedule.times[phase] ?? TimeOfDay(hour: 0)
                return Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
            },
            set: { model.setTime(TimeOfDay($0), for: phase) }
        )
    }
}

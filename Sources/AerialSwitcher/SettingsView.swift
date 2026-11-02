import AerialCore
import SwiftUI

enum SettingsTab: String, CaseIterable {
    case aerials, general, about

    var title: String {
        switch self {
        case .aerials: "Aerials"
        case .general: "General"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .aerials: "mountain.2"
        case .general: "gearshape"
        case .about: "info.circle"
        }
    }
}

/// A classic preferences window: icon tabs on top, right-aligned labels below.
struct SettingsView: View {
    let model: AppModel
    /// For the window to follow: the tab shown, and the size the content needs.
    let onTabChange: (SettingsTab) -> Void
    let onSizeChange: (CGSize) -> Void
    @AppStorage("settingsTab") private var tab = SettingsTab.aerials

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases, id: \.self) { item in
                    TabButton(tab: item, isSelected: item == tab) {
                        withAnimation(.easeInOut(duration: 0.2)) { tab = item }
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)

            Group {
                switch tab {
                case .aerials: AerialsPane(model: model)
                case .general: GeneralPane(model: model)
                case .about: AboutPane()
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { onSizeChange($0) }
        .onChange(of: tab, initial: true) { onTabChange(tab) }
        // While the window animates to the new size, keep the content pinned to the top
        // (minHeight 0: a taller tab is cut off at the bottom rather than re-centered).
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
        .clipped()
    }
}

private struct TabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 22))
                    .frame(height: 26)
                Text(tab.title)
                    .font(.system(size: 12))
            }
            .frame(minWidth: 64)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

private struct AerialsPane: View {
    let model: AppModel

    var body: some View {
        Form {
            LabeledContent("Set") {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Set", selection: Binding(
                        get: { model.config.setID ?? "" },
                        set: { model.selectSet($0) }
                    )) {
                        if model.config.setID == nil { Text("Choose…").tag("") }
                        ForEach(model.sets) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden()
                    .fixedSize()

                    if let download = model.download {
                        ProgressView(value: (Double(download.index) + download.fraction) / Double(download.count))
                            .frame(width: 200)
                        Caption(downloadTitle(download))
                    } else {
                        Caption("One place, filmed at different times of day.")
                    }
                }
            }

            if let set = model.selectedSet, let schedule = model.schedule {
                Spacer().frame(height: 12)
                ForEach(set.aerials) { aerial in
                    DatePicker(aerial.phase.title, selection: time(for: aerial.phase, in: schedule), displayedComponents: .hourAndMinute)
                        .datePickerStyle(.field)
                }
                LabeledContent("") {
                    Button("Reset to Defaults") { model.resetSchedule() }
                        .disabled(model.config.schedules[set.id] == nil)
                }
            }

            if let error = model.error {
                LabeledContent("") {
                    Text(error).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.columns)
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

private struct GeneralPane: View {
    let model: AppModel

    var body: some View {
        Form {
            LabeledContent("Startup") {
                Toggle("Launch at Login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            }
            LabeledContent("Switching") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Paused", isOn: Binding(get: { model.config.paused }, set: { _ in model.togglePause() }))
                        .disabled(model.selectedSet == nil)
                    Caption("Keeps the current wallpaper until resumed.")
                }
            }
            if model.hasBackup {
                LabeledContent("Original Wallpaper") {
                    VStack(alignment: .leading, spacing: 6) {
                        Button("Restore") { model.restoreOriginalWallpaper() }
                        Caption("Puts back the wallpaper you had before and pauses switching.")
                    }
                }
            }
        }
        .formStyle(.columns)
    }
}

private struct AboutPane: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Aerial Switcher").font(.title2.bold())
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                .foregroundStyle(.secondary)
            Text("Follows a Landscape Aerial through the day.")
                .padding(.top, 4)
            Link("github.com/YnNJU/aerial-switcher", destination: URL(string: "https://github.com/YnNJU/aerial-switcher")!)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct Caption: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

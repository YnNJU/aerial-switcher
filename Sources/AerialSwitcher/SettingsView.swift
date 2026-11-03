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
        VStack(alignment: .leading, spacing: 20) {
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
            }
            .formStyle(.columns)

            if let set = model.selectedSet, let schedule = model.schedule {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Schedule").font(.headline)
                        Spacer()
                        Button("Reset to Defaults") { model.resetSchedule() }
                            .controlSize(.small)
                            .disabled(model.config.schedules[set.id] == nil)
                    }
                    ScheduleBar(schedule: schedule, current: model.currentPhase) { phase, time, commit in
                        model.setTime(time, for: phase, commit: commit)
                    }
                    Caption("Drag a handle to change when that part of the day begins.")
                }
            }

            if let error = model.error {
                Text(error).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func downloadTitle(_ download: AppModel.Download) -> String {
        let size = download.totalBytes.map { " · " + ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? ""
        return "Downloading \(download.index + 1) of \(download.count)\(size)"
    }
}

private struct GeneralPane: View {
    let model: AppModel

    var body: some View {
        Form {
            LabeledContent("Startup") {
                Toggle("Launch at Login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            }
            LabeledContent("Wallpaper") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Switch Wallpaper", isOn: Binding(get: { model.config.enabled }, set: { model.setEnabled($0) }))
                        .disabled(model.selectedSet == nil)
                    Caption("When off, the wallpaper you had before is put back.")
                    Toggle("Pause", isOn: Binding(get: { model.config.paused }, set: { model.setPaused($0) }))
                        .disabled(model.selectedSet == nil || !model.config.enabled)
                        .padding(.top, 4)
                    Caption("Keeps the Aerial showing now until unpaused.")
                }
            }
        }
        .formStyle(.columns)
    }
}

private struct AboutPane: View {
    /// The GitHub mark (Octicons `mark-github`), as SVG: AppKit draws it, no image file needed.
    static let githubMark: NSImage = {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="16" height="16"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>"#
        let image = NSImage(data: Data(svg.utf8)) ?? NSImage()
        image.isTemplate = true
        return image
    }()

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
            Link(destination: URL(string: "https://github.com/YnNJU/aerial-switcher")!) {
                Image(nsImage: Self.githubMark)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Aerial Switcher on GitHub")
            .padding(.top, 4)
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

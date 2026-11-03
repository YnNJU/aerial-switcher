import AerialCore
import AppKit
import Observation
import ServiceManagement

@MainActor @Observable
final class AppModel {
    struct Download {
        var index: Int
        var count: Int
        var fraction: Double
        var totalBytes: Int64?
    }

    private(set) var sets: [AerialSet] = []
    private(set) var config: Config
    private(set) var result: SyncResult?
    private(set) var error: String?
    private(set) var download: Download?
    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    private(set) var now = Date()

    private let paths = Paths.live
    private let switcher: Switcher
    /// The phase last put on screen. The wallpaper is only touched again when the phase
    /// changes (or after waking), so picking another wallpaper by hand isn't undone a minute later.
    private var shownPhase: DayPhase?
    private var downloadTask: Task<Void, Never>?
    private var downloadID = UUID()

    init() {
        config = Config.load(from: paths.config)
        switcher = Switcher(paths: paths)
        loadSets()
        startClock()
        observeSystemEvents()
        sync(force: true)
        downloadMissing()
    }

    var selectedSet: AerialSet? { sets.first { $0.id == config.setID } }
    var schedule: Schedule? { selectedSet.map(config.schedule(for:)) }
    var currentPhase: DayPhase? { schedule?.phase(at: now) }
    var nextChange: (date: Date, phase: DayPhase)? { schedule?.nextChange(after: now) }

    // MARK: - Actions

    func selectSet(_ id: String) {
        guard id != config.setID else { return }
        config.setID = id
        // Picking a set means wanting to see it.
        config.enabled = true
        config.paused = false
        save()
        cancelDownload()
        downloadMissing()
    }

    /// While dragging, `commit` is false: the schedule on screen follows, but it's only saved,
    /// and the wallpaper only switched, once the drag ends.
    func setTime(_ time: TimeOfDay, for phase: DayPhase, commit: Bool = true) {
        guard let set = selectedSet else { return }
        var schedule = config.schedule(for: set)
        schedule.times[phase] = time
        config.schedules[set.id] = schedule
        if commit { save() }
    }

    func resetSchedule() {
        guard let set = selectedSet else { return }
        config.schedules[set.id] = nil
        save()
    }

    func setPaused(_ paused: Bool) {
        guard paused != config.paused else { return }
        config.paused = paused
        save()
    }

    /// Turning off puts back the wallpaper from before the app took over; turning on again
    /// takes over again (keeping a fresh copy of whatever is showing then).
    func setEnabled(_ enabled: Bool) {
        guard enabled != config.enabled else { return }
        config.enabled = enabled
        // Pause keeps an Aerial on screen; off and back on there is none to keep.
        config.paused = false
        save()
        guard !enabled else { return }
        do {
            if try switcher.store.restoreBackup() { WallpaperStore.reloadAgent() }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            self.error = "Couldn't change Launch at Login: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Syncing

    private func save() {
        do {
            try config.save(to: paths.config)
        } catch {
            self.error = "Couldn't save settings: \(error.localizedDescription)"
        }
        sync(force: true)
    }

    func sync(force: Bool = false) {
        now = Date()
        let phase = currentPhase
        guard force || phase != shownPhase else { return }
        do {
            result = try switcher.sync(set: selectedSet, config: config, at: now)
            error = nil
            switch result {
            case .switched, .alreadyShowing: shownPhase = phase
            default: shownPhase = nil
            }
        } catch {
            self.error = error.localizedDescription
            shownPhase = nil
        }
    }

    private func loadSets() {
        do {
            sets = try Manifest.load(from: paths.manifest)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func startClock() {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                self?.sync()
            }
        }
    }

    private func observeSystemEvents() {
        let names: [(NotificationCenter, Notification.Name)] = [
            (NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.sessionDidBecomeActiveNotification),
            (.default, .NSSystemClockDidChange),
            (.default, .NSSystemTimeZoneDidChange),
        ]
        for (center, name) in names {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.sync(force: true) }
            }
        }
    }

    // MARK: - Downloads

    /// Downloads the chosen set's missing videos one by one, then switches.
    func downloadMissing() {
        guard downloadTask == nil, let set = selectedSet else { return }
        let missing = switcher.videos.missing(in: set)
        guard !missing.isEmpty else { return }

        let id = UUID()
        downloadID = id
        download = Download(index: 0, count: missing.count, fraction: 0)
        downloadTask = Task {
            let videos = switcher.videos
            let total = await videos.downloadSize(of: missing)
            if downloadID == id { download?.totalBytes = total }

            var failure: String?
            for (index, aerial) in missing.enumerated() {
                guard downloadID == id else { return }
                download?.index = index
                download?.fraction = 0
                do {
                    try await videos.download(aerial) { fraction in
                        Task { @MainActor in
                            guard self.downloadID == id else { return }
                            self.download?.fraction = fraction
                        }
                    }
                } catch {
                    failure = "Downloading \(aerial.label) failed: \(error.localizedDescription)"
                    break
                }
            }

            guard downloadID == id else { return }
            downloadTask = nil
            download = nil
            sync(force: true)
            if let failure { error = failure }
        }
    }

    private func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        download = nil
        downloadID = UUID()
    }
}

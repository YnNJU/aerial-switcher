import Foundation
import Testing
@testable import AerialCore

@Suite struct ManifestTests {
    @Test func findsOnlyDayCycleSets() {
        #expect(Fixtures.sets.map(\.name) == ["Golden Gate", "Tahoe"])
    }

    @Test func sortsAerialsByTimeOfDay() {
        #expect(Fixtures.tahoe.aerials.map(\.phase) == [.morning, .day, .evening, .night])
        #expect(Fixtures.sets[0].aerials.map(\.phase) == [.day, .sunset, .night])
    }

    @Test func usesNamesFromTheStringsTable() throws {
        let chinese = Strings(Fixtures.strings.tables, preferredLanguages: ["zh-Hans-CN"])
        let goldenGate = try #require(Manifest.sets(from: Fixtures.manifest, strings: chinese).first)
        #expect(goldenGate.name == "金门海峡")
        #expect(goldenGate.aerials.map(\.label) == ["金门海峡白天", "Golden Gate Sunset", "Golden Gate Night"])
    }

    @Test func defaultScheduleStartsTheFirstPhaseAtSix() {
        let goldenGate = Fixtures.sets[0].defaultSchedule
        #expect(goldenGate.times == [.day: TimeOfDay(hour: 6), .sunset: TimeOfDay(hour: 17), .night: TimeOfDay(hour: 21)])
    }

    @Test(.enabled(if: FileManager.default.fileExists(atPath: Paths.live.manifest.path)))
    func readsTheRealManifest() throws {
        let ids = try Manifest.load(from: Paths.live.manifest).map(\.id)
        // Golden Gate, Tahoe, Sequoia; Sonoma is not a day cycle.
        #expect(ids.contains { $0.hasPrefix("67512508") })
        #expect(ids.contains { $0.hasPrefix("0DC99DD8") })
        #expect(ids.contains { $0.hasPrefix("78D1B993") })
        #expect(!ids.contains { $0.hasPrefix("3CC63110") })
    }
}

@Suite struct ScheduleTests {
    let schedule = Fixtures.tahoe.defaultSchedule  // 06:00 morning, 12:00 day, 18:00 evening, 21:00 night
    let calendar = Fixtures.calendar

    @Test(arguments: [
        (5, 59, DayPhase.night), (6, 0, .morning), (11, 59, .morning), (12, 0, .day),
        (18, 30, .evening), (21, 0, .night), (23, 59, .night), (0, 0, .night),
    ])
    func phaseWrapsAroundMidnight(hour: Int, minute: Int, expected: DayPhase) {
        #expect(schedule.phase(at: Fixtures.date(hour, minute), calendar: calendar) == expected)
    }

    @Test func nextChangeIsLaterToday() throws {
        let next = try #require(schedule.nextChange(after: Fixtures.date(13), calendar: calendar))
        #expect(next.date == Fixtures.date(18))
        #expect(next.phase == .evening)
    }

    @Test func nextChangeRollsOverToTomorrow() throws {
        let next = try #require(schedule.nextChange(after: Fixtures.date(22), calendar: calendar))
        #expect(next.date == Fixtures.date(6).addingTimeInterval(86_400))
        #expect(next.phase == .morning)
    }

    @Test func tiedTimesShowTheLaterPhase() {
        let tied = Schedule([.morning: TimeOfDay(hour: 6), .day: TimeOfDay(hour: 6), .night: TimeOfDay(hour: 20)])
        #expect(tied.phase(at: Fixtures.date(7), calendar: calendar) == .day)
        #expect(tied.nextChange(after: Fixtures.date(21), calendar: calendar)?.phase == .day)
    }

    @Test func emptyScheduleHasNoPhase() {
        #expect(Schedule([:]).phase(at: Fixtures.date(12), calendar: calendar) == nil)
    }
}

@Suite struct WallpaperStoreTests {
    @Test func readsState() throws {
        #expect(try WallpaperStore(paths: Fixtures.paths(store: Fixtures.store(Fixtures.aerialChoice))).state() == .aerial(assetID: "OLD"))
        #expect(try WallpaperStore(paths: Fixtures.paths(store: Fixtures.store(Fixtures.defaultChoice))).state() == .systemDefault)
        #expect(try WallpaperStore(paths: Fixtures.paths(store: Fixtures.store(Fixtures.imageChoice))).state() == .other)
    }

    @Test func setsAnyWallpaperToTheAerial() throws {
        for choice in [Fixtures.aerialChoice, Fixtures.imageChoice, Fixtures.defaultChoice] {
            let store = WallpaperStore(paths: try Fixtures.paths(store: Fixtures.store(choice)))
            #expect(try store.setAerial("NEW") == 2)
            #expect(try store.state() == .aerial(assetID: "NEW"))
        }
    }

    @Test func keepsTheOriginalForRestore() throws {
        let store = WallpaperStore(paths: try Fixtures.paths(store: Fixtures.store(Fixtures.imageChoice)))
        try store.setAerial("A")
        try store.setAerial("B")
        try store.restoreBackup()
        #expect(try store.state() == .other)
        #expect(!store.hasBackup)
    }

    @Test func backsUpAWallpaperPickedSince() throws {
        let paths = try Fixtures.paths(store: Fixtures.store(Fixtures.imageChoice))
        let store = WallpaperStore(paths: paths)
        try store.setAerial("A")
        // The user picks the system default by hand; the next switch keeps that instead.
        try Fixtures.write(Fixtures.store(Fixtures.defaultChoice), to: paths)
        try store.setAerial("B")
        try store.restoreBackup()
        #expect(try store.state() == .systemDefault)
    }

    @Test func leavesAWallpaperPickedSinceOnRestore() throws {
        let paths = try Fixtures.paths(store: Fixtures.store(Fixtures.imageChoice))
        let store = WallpaperStore(paths: paths)
        try store.setAerial("A")
        try Fixtures.write(Fixtures.store(Fixtures.defaultChoice), to: paths)
        #expect(try store.restoreBackup() == false)
        #expect(try store.state() == .systemDefault)
        #expect(!store.hasBackup)
    }

    @Test func restoresABackupFromVersion1_0_0() throws {
        let paths = try Fixtures.paths(store: Fixtures.store(Fixtures.imageChoice))
        let store = WallpaperStore(paths: paths)
        try store.setAerial("A")
        try FileManager.default.removeItem(at: paths.lastSet)
        #expect(try store.restoreBackup())
        #expect(try store.state() == .other)
    }

    @Test func leavesAnImageScreenSaverAlone() throws {
        var scope = Fixtures.store(Fixtures.imageChoice)["AllSpacesAndDisplays"] as! [String: Any]
        scope["Idle"] = ["Content": ["Choices": [Fixtures.imageChoice]]]
        let paths = try Fixtures.paths(store: ["AllSpacesAndDisplays": scope])
        #expect(try WallpaperStore(paths: paths).setAerial("NEW") == 1)
        let saved = NSDictionary(contentsOf: paths.store)!
        let idle = (saved.value(forKeyPath: "AllSpacesAndDisplays.Idle.Content.Choices") as! [NSDictionary])[0]
        #expect(idle["Provider"] as? String == "com.apple.wallpaper.choice.image")
    }

    @Test func missingStoreThrows() {
        let paths = Paths(home: URL(fileURLWithPath: "/nonexistent"))
        #expect(throws: AerialError.self) { try WallpaperStore(paths: paths).state() }
    }
}

@Suite struct SwitcherTests {
    let set = Fixtures.tahoe
    let config = Config(setID: "tahoe")

    func switcher(_ paths: Paths) -> Switcher {
        Switcher(paths: paths, reload: {})
    }

    @Test func switchesToTheCurrentPhase() throws {
        let paths = try Fixtures.paths(store: Fixtures.store(Fixtures.imageChoice))
        try Fixtures.download(["TA-EVENING"], into: paths)
        let result = try switcher(paths).sync(set: set, config: config, at: Fixtures.date(19), calendar: Fixtures.calendar)
        #expect(result == .switched(to: set.aerial(for: .evening)!))
        #expect(try WallpaperStore(paths: paths).state() == .aerial(assetID: "TA-EVENING"))
    }

    @Test func doesNothingWhenAlreadyShowing() throws {
        let paths = try Fixtures.paths(store: Fixtures.store(Fixtures.choice(provider: "com.apple.wallpaper.choice.aerials", config: ["assetID": "TA-DAY"])))
        try Fixtures.download(["TA-DAY"], into: paths)
        let result = try switcher(paths).sync(set: set, config: config, at: Fixtures.date(13), calendar: Fixtures.calendar)
        #expect(result == .alreadyShowing(set.aerial(for: .day)!))
        #expect(!WallpaperStore(paths: paths).hasBackup)
    }

    @Test func waitsForTheDownload() throws {
        let paths = try Fixtures.paths(store: Fixtures.store(Fixtures.imageChoice))
        let result = try switcher(paths).sync(set: set, config: config, at: Fixtures.date(13), calendar: Fixtures.calendar)
        #expect(result == .notDownloaded(set.aerial(for: .day)!))
        #expect(try WallpaperStore(paths: paths).state() == .other)
    }

    @Test func respectsOffPauseAndCustomTimes() throws {
        let paths = try Fixtures.paths(store: Fixtures.store(Fixtures.imageChoice))
        try Fixtures.download(["TA-NIGHT"], into: paths)
        var config = config
        config.enabled = false
        #expect(try switcher(paths).sync(set: set, config: config, at: Fixtures.date(13), calendar: Fixtures.calendar) == .disabled)
        config.enabled = true
        config.paused = true
        #expect(try switcher(paths).sync(set: set, config: config, at: Fixtures.date(13), calendar: Fixtures.calendar) == .paused)
        config.paused = false
        config.schedules["tahoe"] = Schedule([.morning: TimeOfDay(hour: 6), .night: TimeOfDay(hour: 12, minute: 30)])
        #expect(try switcher(paths).sync(set: set, config: config, at: Fixtures.date(13), calendar: Fixtures.calendar) == .switched(to: set.aerial(for: .night)!))
    }
}

@Suite struct ConfigTests {
    @Test func roundTripsAsReadableJSON() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).json")
        let config = Config(setID: "tahoe", schedules: ["tahoe": Schedule([.morning: TimeOfDay(hour: 6, minute: 30)])])
        try config.save(to: url)
        #expect(Config.load(from: url) == config)
        #expect(try String(contentsOf: url, encoding: .utf8).contains("\"morning\" : \"06:30\""))
    }

    @Test func readsSettingsFromVersion1_0_0() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).json")
        try Data(#"{"paused": true, "schedules": {}, "setID": "tahoe"}"#.utf8).write(to: url)
        #expect(Config.load(from: url) == Config(setID: "tahoe", enabled: true, paused: true))
    }

    @Test func missingFileGivesDefaults() {
        #expect(Config.load(from: URL(fileURLWithPath: "/nonexistent.json")) == Config())
    }
}

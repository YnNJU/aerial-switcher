import Foundation

func fail(_ message: String) -> NSError {
    NSError(domain: "aerial-switcher", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}

struct Phase {
    let name: String
    let label: String
    let start: Int
}

let manifestURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json")
let storeURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
let providerID = "com.apple.wallpaper.choice.aerials"

@main
enum AerialSwitcher {
    static func main() {
        do {
            try run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}

func run(_ arguments: [String]) throws {
    guard let command = arguments.first else {
        throw fail(usage)
    }

    switch command {
    case "auto":
        let args = Array(arguments.dropFirst())
        let combo = try combo(from: args)
        let phase = try currentPhase(for: combo, arguments: args)
        guard let assetID = try manifest()[phase.label.lowercased()] else {
            throw fail("No Aerial asset matched label '\(phase.label)'.")
        }
        print("Combo: \(combo.capitalized)")
        print("Phase: \(phase.name)")
        print("Asset: \(phase.label) (\(assetID))")
        try switchWallpaper(to: assetID, reload: !args.contains("--no-reload"), dryRun: args.contains("--dry-run"))
    case "help", "--help", "-h":
        print(usage)
    default:
        throw fail("Unsupported command '\(command)'.")
    }
}

func combo(from arguments: [String]) throws -> String {
    guard let value = value(after: "--combo", in: arguments) else { return "tahoe" }
    let normalized = value.lowercased()
    guard normalized == "tahoe" || normalized == "sequoia" else {
        throw fail("Unsupported combo '\(value)'. Use tahoe or sequoia.")
    }
    return normalized
}

func currentPhase(for combo: String, arguments: [String]) throws -> Phase {
    let phases = try phaseTemplates(for: combo).map { phase in
        Phase(name: phase.name, label: phase.label, start: try hhmm(value(after: "--\(phase.name)-start", in: arguments) ?? String(format: "%04d", phase.start)))
    }.sorted { $0.start < $1.start }

    let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
    let current = (now.hour ?? 0) * 100 + (now.minute ?? 0)

    for index in phases.indices {
        let phase = phases[index]
        let next = phases[(index + 1) % phases.count].start
        if phase.start <= next {
            if current >= phase.start && current < next { return phase }
        } else if current >= phase.start || current < next {
            return phase
        }
    }

    guard let phase = phases.last else { throw fail("No phases configured.") }
    return phase
}

func phaseTemplates(for combo: String) -> [Phase] {
    combo == "sequoia"
        ? [
            Phase(name: "morning", label: "Sequoia Morning", start: 600),
            Phase(name: "sunrise", label: "Sequoia Sunrise", start: 1200),
            Phase(name: "night", label: "Sequoia Night", start: 2100)
        ]
        : [
            Phase(name: "morning", label: "Tahoe Morning", start: 600),
            Phase(name: "day", label: "Tahoe Day", start: 1200),
            Phase(name: "evening", label: "Tahoe Evening", start: 1800),
            Phase(name: "night", label: "Tahoe Night", start: 2200)
        ]
}

func manifest() throws -> [String: String] {
    let data: Data
    do {
        data = try Data(contentsOf: manifestURL)
    } catch {
        throw fail("Failed to load the Aerial manifest.")
    }

    guard
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let assets = json["assets"] as? [[String: Any]]
    else {
        throw fail("Failed to load the Aerial manifest.")
    }

    return assets.reduce(into: [:]) { result, asset in
        if let id = asset["id"] as? String, let label = asset["accessibilityLabel"] as? String {
            result[label.lowercased()] = id
        }
    }
}

func switchWallpaper(to assetID: String, reload: Bool, dryRun: Bool) throws {
    guard
        let store = NSDictionary(contentsOf: storeURL),
        let mutableStore = deepMutableCopy(store) as? NSMutableDictionary
    else {
        throw fail("Failed to load the wallpaper store.")
    }

    let updatedEntries = try updateStore(mutableStore, assetID: assetID)

    if dryRun {
        print("Dry run: would update \(updatedEntries) Aerial entry(s) to asset \(assetID)")
        return
    }

    do {
        let data = try PropertyListSerialization.data(fromPropertyList: mutableStore, format: .binary, options: 0)
        try data.write(to: storeURL, options: .atomic)
    } catch {
        throw fail("Failed to write updated wallpaper store: \(error.localizedDescription)")
    }

    print("Updated \(updatedEntries) Aerial entry(s) to asset \(assetID)")

    if reload {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["WallpaperAgent"]
        try? process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
            print("Reloaded WallpaperAgent")
        }
    }
}

func updateStore(_ store: NSMutableDictionary, assetID: String) throws -> Int {
    let timestamp = Date() as NSDate
    var count = 0

    for key in ["AllSpacesAndDisplays", "SystemDefault"] {
        if let scope = store[key] as? NSMutableDictionary {
            count += try updateScope(scope, assetID: assetID, timestamp: timestamp)
        }
    }

    for key in ["Displays", "Spaces"] {
        if let container = store[key] as? NSMutableDictionary {
            for (_, value) in container {
                if let scope = value as? NSMutableDictionary {
                    count += try updateScope(scope, assetID: assetID, timestamp: timestamp)
                }
            }
        }
    }

    if count == 0 { throw fail("No active Aerial wallpaper entries were found in the wallpaper store.") }
    return count
}

func updateScope(_ scope: NSMutableDictionary, assetID: String, timestamp: NSDate) throws -> Int {
    var count = 0

    for key in ["Linked", "Desktop", "Idle", "ScreenSaver"] {
        guard
            let entry = scope[key] as? NSMutableDictionary,
            let content = entry["Content"] as? NSMutableDictionary,
            let choices = content["Choices"] as? NSMutableArray
        else {
            continue
        }

        var changed = false
        for index in 0..<choices.count {
            guard
                let choice = choices[index] as? NSMutableDictionary,
                choice["Provider"] as? String == providerID,
                let data = choice["Configuration"] as? Data,
                let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                let config = (plist as? NSDictionary)?.mutableCopy() as? NSMutableDictionary
            else {
                continue
            }

            config["assetID"] = assetID
            choice["Configuration"] = try PropertyListSerialization.data(fromPropertyList: config, format: .binary, options: 0)
            changed = true
        }

        if changed {
            entry["LastSet"] = timestamp
            entry["LastUse"] = timestamp
            count += 1
        }
    }

    return count
}

func deepMutableCopy(_ value: Any) -> Any {
    switch value {
    case let dictionary as NSDictionary:
        let copy = NSMutableDictionary(capacity: dictionary.count)
        for (key, nestedValue) in dictionary { copy[key] = deepMutableCopy(nestedValue) }
        return copy
    case let array as NSArray:
        let copy = NSMutableArray(capacity: array.count)
        for nestedValue in array { copy.add(deepMutableCopy(nestedValue)) }
        return copy
    default:
        return value
    }
}

func value(after flag: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
    return arguments[index + 1]
}

let usage = "Usage: aerial-switcher auto [--combo <tahoe|sequoia>] [--morning-start <HHmm>] [--day-start <HHmm>] [--evening-start <HHmm>] [--sunrise-start <HHmm>] [--night-start <HHmm>]"

func hhmm(_ value: String) throws -> Int {
    guard value.count == 4, value.allSatisfy(\.isNumber), let number = Int(value) else {
        throw fail("Invalid time '\(value)'. Use HHmm.")
    }
    let hour = number / 100
    let minute = number % 100
    guard (0...23).contains(hour), (0...59).contains(minute) else {
        throw fail("Invalid time '\(value)'. Use HHmm.")
    }
    return number
}

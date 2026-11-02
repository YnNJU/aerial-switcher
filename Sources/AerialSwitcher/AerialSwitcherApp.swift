import AerialCore
import SwiftUI

@main
struct AerialSwitcherApp: App {
    // A plain `let` rather than @State: the App is created once, and SwiftUI's macros
    // (@State is one) aren't available when building with the Command Line Tools alone.
    private let model: AppModel

    init() {
        // Menu bar only, also when run outside an .app bundle (swift run).
        NSApplication.shared.setActivationPolicy(.accessory)
        model = AppModel()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.currentPhase?.symbol ?? "mountain.2")
        }

        Window("Aerial Switcher", id: "settings") {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(model.config.setID == nil ? .presented : .suppressed)
    }
}

extension DayPhase {
    var symbol: String {
        switch self {
        case .sunrise: "sunrise"
        case .morning: "sun.haze"
        case .day: "sun.max"
        case .sunset: "sunset"
        case .evening: "sun.horizon"
        case .night: "moon.stars"
        }
    }
}

import AerialCore
import SwiftUI

@main
struct AerialSwitcherApp: App {
    // A plain `let` rather than @State: the App is created once, and SwiftUI's macros
    // (@State is one) aren't available when building with the Command Line Tools alone.
    private let model: AppModel
    private let settings: SettingsWindow
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    init() {
        // Menu bar only, also when run outside an .app bundle (swift run).
        NSApplication.shared.setActivationPolicy(.accessory)
        model = AppModel()
        settings = SettingsWindow(model: model)
        if model.config.setID == nil {
            DispatchQueue.main.async { [settings] in settings.show() }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.currentPhase?.symbol ?? "mountain.2")
        }
    }
}

/// Opening the app again while it runs shows Settings, so it can be reached even when
/// the menu bar icon is hidden behind the notch or by a menu bar manager.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        NotificationCenter.default.post(name: .showSettings, object: nil)
        return false
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

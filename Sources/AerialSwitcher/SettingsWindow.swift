import AppKit
import SwiftUI

/// The settings window, hosted in AppKit rather than a SwiftUI `Window` scene: a scene
/// window jumps to its content's new size, while this one animates like a preferences
/// window should when switching tabs.
@MainActor
final class SettingsWindow {
    private let model: AppModel
    private var window: NSWindow?
    /// The size the content last asked for; it can arrive before the window exists.
    private var contentSize: CGSize?

    init(model: AppModel) {
        self.model = model
        // Opening the app again while it runs (see AppDelegate) and the menu's Settings… item.
        NotificationCenter.default.addObserver(forName: .showSettings, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.show() }
        }
    }

    func show() {
        let window = window ?? makeWindow()
        // In the Dock and ⌘Tab while Settings is open; back to menu bar only once closed.
        NSApp.setActivationPolicy(.regular)
        // From the menu bar the app isn't active, and a plain activate() is only a request
        // the system may turn down; bring the window up regardless, then activate once the
        // policy change has taken effect.
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    }

    private func makeWindow() -> NSWindow {
        let view = SettingsView(
            model: model,
            onTabChange: { [weak self] tab in self?.window?.title = tab.title },
            onSizeChange: { [weak self] size in
                self?.contentSize = size
                // Not during SwiftUI's layout pass: an animated resize started there can
                // complete at once.
                DispatchQueue.main.async { self?.resize() }
            }
        )
        let hosting = NSHostingController(rootView: view)
        // The window's size is set by resize(to:), animated.
        hosting.sizingOptions = []
        let window = PreferencesWindow(contentViewController: hosting)
        // One surface from the title bar down, like the SwiftUI window had.
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isReleasedWhenClosed = false
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated { _ = NSApp.setActivationPolicy(.accessory) }
        }
        self.window = window
        hosting.view.layoutSubtreeIfNeeded()
        resize()
        window.center()
        return window
    }

    private func resize() {
        guard let window, let size = contentSize, size != window.contentLayoutRect.size else { return }
        // The content runs under the title bar, so add the title bar's height back.
        let titleBar = window.frame.height - window.contentLayoutRect.height
        let height = size.height + titleBar
        // Keep the top edge in place, as the content grows and shrinks downwards.
        let frame = NSRect(x: window.frame.minX, y: window.frame.maxY - height, width: size.width, height: height)
        window.setFrame(frame, display: true, animate: window.isVisible)
    }
}

/// AppKit scales resize animations by distance, so the small steps between tabs
/// (a few dozen points) finish in a blink; use a fixed, noticeable duration instead.
private final class PreferencesWindow: NSWindow {
    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval { 0.25 }
}

extension Notification.Name {
    static let showSettings = Notification.Name("showSettings")
}

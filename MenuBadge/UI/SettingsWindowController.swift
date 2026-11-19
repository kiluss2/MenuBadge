import AppKit
import BadgeKit
import SwiftUI

/// Owns the single Settings window. Closing it drops its views, so previews stop animating.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let store: SettingsStore
    private let engine: BadgeEngine
    private let updater: UpdateChecker
    private var window: NSWindow?

    init(store: SettingsStore, engine: BadgeEngine, updater: UpdateChecker) {
        self.store = store
        self.engine = engine
        self.updater = updater
        super.init()
    }

    func show(selecting selection: SidebarItem = .general) {
        if window == nil {
            let root = SettingsView(store: store, engine: engine, initialSelection: selection)
                .environment(updater)
            let window = NSWindow(contentViewController: NSHostingController(rootView: root))
            window.title = "MenuBadge"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.setContentSize(NSSize(width: 760, height: 560))
            window.isReleasedWhenClosed = false
            window.center()
            window.setFrameAutosaveName("MenuBadgeSettings")
            window.delegate = self
            self.window = window
        }
        // A menu bar app is not active when its menu is used, and macOS may turn down the
        // activation; bring the window to the front anyway so one click is enough.
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        parkColorPanel()
    }

    /// The colour wells open the shared Colors panel wherever it last was, often a corner of
    /// another screen; keep it beside this window while it is closed so it opens next to it.
    private func parkColorPanel() {
        guard let window, let screen = window.screen else { return }
        let panel = NSColorPanel.shared
        guard !panel.isVisible else { return }
        panel.setFrame(PanelPlacement.beside(window.frame, panel: panel.frame.size, in: screen.visibleFrame),
                       display: false)
    }

    func windowDidMove(_ notification: Notification) { parkColorPanel() }

    func windowDidResize(_ notification: Notification) { parkColorPanel() }

    func windowWillClose(_ notification: Notification) {
        window?.contentViewController = nil
        window?.delegate = nil
        window = nil
    }
}

import AppKit
import BadgeKit
import SwiftUI

/// Owns the single Settings window. Closing it drops its views, so previews stop animating.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let store: SettingsStore
    private let engine: BadgeEngine
    private var window: NSWindow?

    init(store: SettingsStore, engine: BadgeEngine) {
        self.store = store
        self.engine = engine
        super.init()
    }

    func show(selecting selection: SidebarItem = .general) {
        if window == nil {
            let root = SettingsView(store: store, engine: engine, initialSelection: selection)
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
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window?.contentViewController = nil
        window?.delegate = nil
        window = nil
    }
}

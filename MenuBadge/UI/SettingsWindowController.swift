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
    /// Watches clicks in this window to open the Colors panel beside the colour well clicked.
    private var clickMonitor: Any?

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
            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                MainActor.assumeIsolated { self?.placeColorPanel(for: event) }
                return event
            }
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

    /// Runs before the click reaches a colour well, so the panel opens right beside that well.
    private func placeColorPanel(for event: NSEvent) {
        guard let window, event.window === window, let content = window.contentView, let screen = window.screen,
              let well = Self.colorWells(in: content).first(where: { well in
                  well.convert(well.bounds, to: nil).contains(event.locationInWindow)
              })
        else { return }
        let wellOnScreen = window.convertToScreen(well.convert(well.bounds, to: nil))
        let panel = NSColorPanel.shared
        panel.setFrame(PanelPlacement.beside(wellOnScreen, panel: panel.frame.size, in: screen.visibleFrame),
                       display: panel.isVisible)
    }

    private static func colorWells(in view: NSView) -> [NSColorWell] {
        if let well = view as? NSColorWell { return [well] }
        return view.subviews.flatMap(colorWells)
    }

    func windowDidMove(_ notification: Notification) { parkColorPanel() }

    func windowDidResize(_ notification: Notification) { parkColorPanel() }

    func windowWillClose(_ notification: Notification) {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
        window?.contentViewController = nil
        window?.delegate = nil
        window = nil
    }
}

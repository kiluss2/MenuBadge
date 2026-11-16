import AppKit
import SwiftUI

/// A card in the top-right corner of the screen in use, for badges that grew while the menu bar
/// was hidden (a full-screen app). It goes away after a few seconds or when clicked.
@MainActor
final class BadgeAlert {
    static let duration: TimeInterval = 6
    static let maxRows = 4

    private var panel: NSPanel?
    private var rows: [AlertRow] = []
    private var hideTimer: Timer?

    /// Adds or refreshes `row` (newest on top) and shows the card for `duration` from now.
    func show(_ row: AlertRow) {
        rows.removeAll { $0.id == row.id }
        rows.insert(row, at: 0)
        rows = Array(rows.prefix(Self.maxRows))
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let host = NSHostingView(rootView: AlertCardView(rows: rows) { [weak self] id in self?.open(id) })
        panel.contentView = host
        let size = host.fittingSize
        let screen = MenuBarWatcher.activeScreen() ?? NSScreen.main
        let area = screen?.frame ?? .zero
        panel.setFrame(CGRect(x: area.maxX - size.width - 16, y: area.maxY - size.height - 16,
                              width: size.width, height: size.height), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        hideTimer?.invalidate()
        let timer = Timer(timeInterval: Self.duration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
        RunLoop.main.add(timer, forMode: .common)
        hideTimer = timer
    }

    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        rows.removeAll()
        panel?.orderOut(nil)
    }

    private func open(_ bundleID: String) {
        hide()
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // Above a full-screen app, on whichever Space is in front, without taking focus.
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        return panel
    }
}

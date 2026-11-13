import AppKit
import BadgeKit

/// MenuBadge's own icon in the menu bar (optional): Settings…, Pause All Badges, Quit.
@MainActor
final class MenuBarItem: NSObject, NSMenuDelegate {
    private let store: SettingsStore
    private let openSettings: () -> Void
    private var item: NSStatusItem?
    private let pauseItem = NSMenuItem(title: "Pause All Badges", action: #selector(togglePause), keyEquivalent: "")

    init(store: SettingsStore, openSettings: @escaping () -> Void) {
        self.store = store
        self.openSettings = openSettings
    }

    /// Adds or removes the icon to match "Show MenuBadge in menu bar".
    func sync() {
        if store.settings.showMenuBarIcon {
            if item == nil { item = makeItem() }
        } else if let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    private func makeItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "app.badge", accessibilityDescription: "MenuBadge")
        image?.isTemplate = true
        item.button?.image = image
        let menu = NSMenu()
        menu.delegate = self
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        pauseItem.target = self
        let quit = NSMenuItem(title: "Quit MenuBadge", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items = [settings, pauseItem, .separator(), quit]
        item.menu = menu
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        pauseItem.state = store.settings.paused ? .on : .off
    }

    @objc private func showSettings() { openSettings() }

    @objc private func togglePause() { store.settings.paused.toggle() }
}

import AppKit
import BadgeKit

/// MenuBadge's own icon in the menu bar: Settings…, Pause All Badges, Quit. Shown when "Show
/// MenuBadge in menu bar" is on, and always in compact mode, where it also carries every badge.
@MainActor
final class MenuBarItem: NSObject, NSMenuDelegate {
    /// One app with a badge, listed at the top of the menu in compact mode.
    struct BadgeRow {
        let bundleID: String
        let name: String
        let text: String
    }

    private let store: SettingsStore
    private let openSettings: () -> Void
    private let badgeRows: () -> [BadgeRow]
    private var item: NSStatusItem?
    /// Adds "Update to X…" when a newer release is known, and "Check for Updates…".
    weak var updater: UpdateChecker?
    private let pauseItem = NSMenuItem(title: "Pause All Badges", action: #selector(togglePause), keyEquivalent: "")
    /// What compact mode shows now; nil = the plain glyph.
    private var compact: (layout: CompactLayout, appearances: [String: BadgeAppearance])?

    init(store: SettingsStore, openSettings: @escaping () -> Void, badgeRows: @escaping () -> [BadgeRow]) {
        self.store = store
        self.openSettings = openSettings
        self.badgeRows = badgeRows
    }

    /// Adds or removes the icon to match "Show MenuBadge in menu bar" and compact mode.
    func sync() {
        if store.settings.showMenuBarIcon || store.settings.compact {
            if item == nil {
                item = makeItem()
                render()
            }
        } else if let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    /// Compact mode: draws `layout` (no badges or nil = the glyph) and plays the new-badge effect
    /// of `grewBundleID`'s look on the whole item.
    func showCompact(_ layout: CompactLayout?, appearances: [String: BadgeAppearance], grewBundleID: String?) {
        if let layout, !layout.shown.isEmpty {
            compact = (layout, appearances)
        } else {
            compact = nil
        }
        sync()
        render()
        if let grewBundleID, let layer = item?.button?.layer {
            BadgeAnimations.playNew((appearances[grewBundleID] ?? .standard).onNew, on: layer)
        }
    }

    private func render() {
        guard let item, let button = item.button else { return }
        if let compact {
            item.length = NSStatusItem.variableLength
            button.image = CompactRenderer.image(compact.layout, appearances: compact.appearances)
        } else {
            item.length = NSStatusItem.squareLength
            button.image = MenuBarGlyph.image
        }
    }

    private func makeItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // Keeps the place the user ⌘-drags the icon to across launches.
        item.autosaveName = "MenuBadge"
        item.isVisible = true
        item.button?.wantsLayer = true
        item.button?.image = MenuBarGlyph.image
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        return item
    }

    /// Rebuilt on every open: the apps with a badge (compact mode), then the fixed items.
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        if store.settings.compact {
            let rows = badgeRows()
            for row in rows { menu.addItem(appItem(row)) }
            if !rows.isEmpty { menu.addItem(.separator()) }
        }
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        pauseItem.target = self
        pauseItem.state = store.settings.paused ? .on : .off
        let check = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        check.target = self
        var items = [settings, pauseItem, check, .separator()]
        if let update = updater?.available {
            let install = NSMenuItem(title: "Update to \(update.version)…", action: #selector(installUpdate), keyEquivalent: "")
            install.target = self
            items.append(install)
        }
        items.append(NSMenuItem(title: "Quit MenuBadge", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for item in items { menu.addItem(item) }
    }

    /// Shows Settings › General, where the check's result appears.
    @objc private func checkForUpdates() {
        Task { @MainActor in
            openSettings()
            await updater?.checkNow(manual: true)
        }
    }

    @objc private func installUpdate() { updater?.install() }

    /// "Slack        3": name on the left, badge text right-aligned; opens the app.
    private func appItem(_ row: BadgeRow) -> NSMenuItem {
        let item = NSMenuItem(title: row.name, action: #selector(openApp(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = row.bundleID
        // The icon goes in the title: this menu showed no `NSMenuItem.image` on macOS 27.
        let font = NSFont.menuFont(ofSize: 0)
        let icon = NSTextAttachment()
        icon.image = AppIconCache.menuIcon(for: row.bundleID)
        icon.bounds = CGRect(x: 0, y: (font.capHeight - 16) / 2, width: 16, height: 16)
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right, location: 200)]
        let title = NSMutableAttributedString(attachment: icon)
        title.append(NSAttributedString(string: "  \(row.name)\t\(row.text)"))
        title.addAttributes([.font: font, .paragraphStyle: style], range: NSRange(location: 0, length: title.length))
        item.attributedTitle = title
        return item
    }

    @objc private func openApp(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Opens Settings once the menu has closed, so the window is not ordered behind the
    /// app that was active when the menu was clicked.
    @objc private func showSettings() {
        Task { @MainActor in openSettings() }
    }

    @objc private func togglePause() { store.settings.paused.toggle() }
}

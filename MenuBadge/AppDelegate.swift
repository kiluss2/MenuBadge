import AppKit
import ApplicationServices
import BadgeKit
import Observation

@main @MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: SettingsStore!
    private var engine: BadgeEngine!
    private var settingsWindow: SettingsWindowController!
    private var menuBarItem: MenuBarItem!
    /// The "Open at login" value last handed to the system; nil until launch reconciled it.
    private var appliedOpenAtLogin: Bool?

    static func main() {
        // Used by scripts/uninstall.sh: drop the login item and exit before starting anything.
        if CommandLine.arguments.contains("--unregister-login-item") {
            LoginItem.unregister()
            exit(0)
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = SettingsStore()
        engine = BadgeEngine(store: store)
        settingsWindow = SettingsWindowController(store: store, engine: engine)
        menuBarItem = MenuBarItem(store: store, openSettings: { [weak self] in self?.settingsWindow.show() },
                                  badgeRows: { [weak self] in self?.engine.compactRows() ?? [] })
        engine.menuBarItem = menuBarItem
        reconcileLoginItem()
        applySettings()
        observeSettings()
        engine.start()

        // MENUBADGE_DEMO=<bundle id> (1 = Slack): run the demo on that app's badge, then quit.
        if let demo = ProcessInfo.processInfo.environment["MENUBADGE_DEMO"] {
            engine.runDemo(bundleID: demo == "1" ? "com.tinyspeck.slackmacgap" : demo, quitWhenDone: true)
            return
        }
        if !AXIsProcessTrusted() {
            // "AXTrustedCheckOptionPrompt" is the value of kAXTrustedCheckOptionPrompt, a C global
            // that Swift 6 refuses to read as non-concurrency-safe.
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            settingsWindow.show(selecting: .general)
        }
    }

    /// Opening MenuBadge again (Spotlight, Launchpad, Finder) opens Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return true
    }

    /// Re-applies what changed; the login item is only touched when its setting changes.
    private func applySettings() {
        menuBarItem.sync()
        let wanted = store.settings.openAtLogin
        if wanted != appliedOpenAtLogin {
            LoginItem.apply(wanted)
            appliedOpenAtLogin = wanted
        }
    }

    private func reconcileLoginItem() {
        guard LoginItem.isInstalledCopy else {
            appliedOpenAtLogin = store.settings.openAtLogin // a dev build never touches login items
            return
        }
        let key = "MenuBadge.loginItemSetUp"
        let result = LoginItemSync.atLaunch(stored: store.settings.openAtLogin, systemEnabled: LoginItem.isEnabled,
                                            setUpBefore: UserDefaults.standard.bool(forKey: key))
        store.settings.openAtLogin = result.setting
        if result.apply { LoginItem.apply(result.setting) }
        appliedOpenAtLogin = result.setting
        UserDefaults.standard.set(true, forKey: key)
    }

    /// Re-applies the menu bar icon, compact mode and login item whenever those settings change.
    private func observeSettings() {
        withObservationTracking {
            _ = store.settings.showMenuBarIcon
            _ = store.settings.openAtLogin
            _ = store.settings.compact
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.applySettings()
                self?.engine.tick() // compact on / off shows at once
                self?.observeSettings()
            }
        }
    }
}

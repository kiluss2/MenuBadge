import AppKit
import ApplicationServices
import BadgeKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: SettingsStore!
    private var engine: BadgeEngine!

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = SettingsStore()
        engine = BadgeEngine(store: store)
        if !AXIsProcessTrusted() {
            // "AXTrustedCheckOptionPrompt" is the value of kAXTrustedCheckOptionPrompt, a C global
            // that Swift 6 refuses to read as non-concurrency-safe.
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        }
        engine.start()
        // MENUBADGE_DEMO=<bundle id> (1 = Slack): run the demo on that app's badge, then quit.
        if let demo = ProcessInfo.processInfo.environment["MENUBADGE_DEMO"] {
            engine.runDemo(bundleID: demo == "1" ? "com.tinyspeck.slackmacgap" : demo, quitWhenDone: true)
        }
    }
}

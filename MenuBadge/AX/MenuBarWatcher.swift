import AppKit
import ApplicationServices
import BadgeKit

/// Whether the menu bar is out of sight right now (a full-screen app, or a menu bar set to hide).
@MainActor
enum MenuBarWatcher {
    static func isHidden() -> Bool {
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        let autoHide = CFPreferencesCopyAppValue("_HIHideMenuBar" as CFString, kCFPreferencesAnyApplication) as? Bool
        let visibleInFullScreen = CFPreferencesCopyAppValue("AppleMenuBarVisibleInFullscreen" as CFString,
                                                            kCFPreferencesAnyApplication) as? Bool
        return MenuBarVisibility.isHidden(frontFullScreen: focusedWindow().map(isFullScreen) ?? false,
                                          autoHide: autoHide ?? false,
                                          visibleInFullScreen: visibleInFullScreen ?? false)
    }

    /// The screen the user is looking at: the one holding the frontmost app's focused window.
    static func activeScreen() -> NSScreen? {
        guard let window = focusedWindow(), let frame = AX.frame(window),
              let primary = NSScreen.screens.first else { return NSScreen.main }
        let cocoa = BadgeGeometry.axToCocoa(frame, primaryScreenMaxY: primary.frame.maxY)
        return NSScreen.screens.max { a, b in
            a.frame.intersection(cocoa).width * a.frame.intersection(cocoa).height
                < b.frame.intersection(cocoa).width * b.frame.intersection(cocoa).height
        } ?? NSScreen.main
    }

    private static func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let window = AX.attr(AX.app(pid: app.processIdentifier), kAXFocusedWindowAttribute),
              CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
        return (window as! AXUIElement)
    }

    private static func isFullScreen(_ window: AXUIElement) -> Bool {
        (AX.attr(window, "AXFullScreen") as? Bool) ?? false
    }
}

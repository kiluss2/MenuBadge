import AppKit
import ApplicationServices

/// Mission Control: its Spaces bar covers the menu bar, and every app's menu bar icon drops out of
/// Accessibility until it closes.
@MainActor
enum MenuBarCover {
    /// Owners of the Mission Control screen: WindowManager on macOS 27, the Dock before it.
    private static let owners: Set<String> = ["com.apple.WindowManager", "com.apple.dock"]

    /// Whether Mission Control owns what is at `axPoint` (AX coordinates) right now.
    static func covers(_ axPoint: CGPoint) -> Bool {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.5)
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(axPoint.x), Float(axPoint.y), &element) == .success,
              let element else { return false }
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success,
              let owner = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier else { return false }
        return owners.contains(owner)
    }
}

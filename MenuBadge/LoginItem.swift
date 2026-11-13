import AppKit
import OSLog
import ServiceManagement

/// "Open at login" through `SMAppService.mainApp`.
@MainActor
enum LoginItem {
    private static let log = Logger(subsystem: "com.kiluss.menubadge", category: "login-item")

    /// Only the installed copy registers, so a debug build in DerivedData never becomes a login item.
    static var isInstalledCopy: Bool {
        let path = Bundle.main.bundleURL.path
        return path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func apply(_ on: Bool) {
        guard isInstalledCopy, on != isEnabled else { return }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            log.error("Open at login \(on ? "on" : "off") failed: \(error.localizedDescription)")
        }
    }
}

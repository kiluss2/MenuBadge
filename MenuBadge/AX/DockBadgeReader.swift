import AppKit
import ApplicationServices

/// Reads the badge text ("3", "•") of apps' Dock tiles. Works while the Dock is auto-hidden.
@MainActor
final class DockBadgeReader {
    private var tiles: [String: AXUIElement] = [:]
    private var bundleIDByPath: [String: String] = [:]
    private var lastScan = Date.distantPast
    /// A running app without a Dock tile (menu bar-only apps) would otherwise rescan every tick.
    private let minScanInterval: TimeInterval = 5

    /// Forget cached tiles (Dock restarted, apps launched or quit).
    func reset() {
        tiles.removeAll()
        lastScan = .distantPast
    }

    func label(for bundleID: String) -> String? {
        if tiles[bundleID] == nil, Date().timeIntervalSince(lastScan) >= minScanInterval { scan() }
        guard let tile = tiles[bundleID] else { return nil }
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(tile, "AXStatusLabel" as CFString, &value)
        if err == .invalidUIElement || err == .cannotComplete {
            tiles[bundleID] = nil
            lastScan = .distantPast
            return nil
        }
        return value as? String
    }

    private func scan() {
        lastScan = Date()
        tiles.removeAll()
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return }
        let dock = AX.app(pid: dockApp.processIdentifier)
        for list in AX.children(dock) where (AX.attr(list, kAXRoleAttribute) as? String) == "AXList" {
            for tile in AX.children(list) {
                guard let url = AX.attr(tile, kAXURLAttribute) as? URL, let id = bundleID(of: url) else { continue }
                tiles[id] = tile
            }
        }
    }

    private func bundleID(of url: URL) -> String? {
        let path = url.standardizedFileURL.path
        if let cached = bundleIDByPath[path] { return cached }
        guard path.hasSuffix(".app"), let id = Bundle(url: url)?.bundleIdentifier else { return nil }
        bundleIDByPath[path] = id
        return id
    }
}

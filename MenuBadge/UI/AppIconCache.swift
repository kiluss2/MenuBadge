import AppKit
import BadgeKit

/// App icons by bundle id, looked up once.
@MainActor
enum AppIconCache {
    private static var icons: [String: NSImage] = [:]
    private static var menuBarIcons: [String: NSImage] = [:]
    private static var menuIcons: [String: NSImage] = [:]

    static func icon(for bundleID: String) -> NSImage {
        if let icon = icons[bundleID] { return icon }
        let icon: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        icons[bundleID] = icon
        return icon
    }

    /// A 16 pt copy for menu items, like the icons in Finder's "Open With" menu.
    static func menuIcon(for bundleID: String) -> NSImage {
        if let icon = menuIcons[bundleID] { return icon }
        let small = (icon(for: bundleID).copy() as? NSImage) ?? NSImage()
        small.size = NSSize(width: 16, height: 16)
        menuIcons[bundleID] = small
        return small
    }

    /// The icon for the menu bar, with the transparent margin app icons are drawn with (about a
    /// fifth of the canvas) cut off, so the artwork is 16 pt like other menu bar icons (Slack's own
    /// is 16 pt) instead of 13.
    static func menuBarIcon(for bundleID: String) -> NSImage {
        if let icon = menuBarIcons[bundleID] { return icon }
        let source = icon(for: bundleID)
        let side = BadgeGeometry.ownItemIconSize
        var proposed = CGRect(x: 0, y: 0, width: 128, height: 128)
        let icon: NSImage
        if let image = source.cgImage(forProposedRect: &proposed, context: nil, hints: nil),
           let visible = ImageTrim.opaqueBounds(of: image), let cropped = image.cropping(to: visible) {
            let scale = side / max(visible.width, visible.height)
            icon = NSImage(cgImage: cropped, size: NSSize(width: visible.width * scale, height: visible.height * scale))
            icon.isTemplate = source.isTemplate
        } else {
            icon = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
                source.draw(in: rect)
                return true
            }
        }
        menuBarIcons[bundleID] = icon
        return icon
    }
}

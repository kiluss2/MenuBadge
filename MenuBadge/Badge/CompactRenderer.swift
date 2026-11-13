import AppKit
import BadgeKit

/// Draws the compact item's image: each shown app's icon with its badge, side by side, and "+N"
/// for the apps that do not fit.
@MainActor
enum CompactRenderer {
    /// Space between two apps.
    static let gap: CGFloat = 4

    static func image(_ layout: CompactLayout, appearances: [String: BadgeAppearance]) -> NSImage {
        let height = NSStatusBar.system.thickness
        let slots = layout.shown.map { badge -> (CompactBadge, BadgeAppearance, CGFloat) in
            let a = appearances[badge.bundleID] ?? .standard
            let badgeWidth = Double(BadgeRenderer.badgeSize(badge.label, a).width)
            let width = CGFloat(BadgeGeometry.ownItemLength(size: a.size, badgeWidth: badgeWidth, iconSize: a.iconSize))
            return (badge, a, width)
        }
        let more = layout.overflow > 0 ? "+\(layout.overflow)" as NSString : nil
        let moreAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .medium),
                                                        .foregroundColor: NSColor.secondaryLabelColor]
        let moreSize = more?.size(withAttributes: moreAttrs) ?? .zero
        let width = slots.map(\.2).reduce(0, +) + gap * CGFloat(max(0, slots.count - 1))
            + (more == nil ? 0 : gap + ceil(moreSize.width))

        // Top-down like AX, so the own item's badge geometry applies as is.
        return NSImage(size: NSSize(width: max(width, 1), height: height), flipped: true) { _ in
            var x: CGFloat = 0
            for (badge, a, slotWidth) in slots {
                let slot = CGRect(x: x, y: 0, width: slotWidth, height: height)
                let icon = AppIconCache.menuBarIcon(for: badge.bundleID, side: a.iconSize)
                let iconRect = CGRect(x: slot.midX - icon.size.width / 2, y: slot.midY - icon.size.height / 2,
                                      width: icon.size.width, height: icon.size.height)
                icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                let image = BadgeRenderer.image(badge.label, a)
                let rect = BadgeGeometry.clamped(
                    BadgeGeometry.badgeRectAX(iconAX: slot, corner: a.corner, badgeSize: image.size, glyphSize: CGFloat(a.iconSize)),
                    to: slot)
                image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                x += slotWidth + gap
            }
            more?.draw(at: CGPoint(x: x, y: (height - moreSize.height) / 2), withAttributes: moreAttrs)
            return true
        }
    }
}

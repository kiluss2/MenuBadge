import CoreGraphics

/// Badge size and position. Icon rects are in AX coordinates (top-left origin, y down).
public enum BadgeGeometry {
    /// The glyph inside a menu bar item is assumed ~16 pt wide, centred in the item.
    static let glyphHalfWidth: CGFloat = 8
    /// Vertical offsets of the glyph's top and bottom edges from the item's centre.
    static let glyphTop: CGFloat = -7
    static let glyphBottom: CGFloat = 6

    /// The glyph corner the badge is centred on.
    public static func anchor(iconAX: CGRect, corner: Corner) -> CGPoint {
        let left = corner == .topLeft || corner == .bottomLeft
        let top = corner == .topLeft || corner == .topRight
        return CGPoint(x: iconAX.midX + (left ? -glyphHalfWidth : glyphHalfWidth),
                       y: iconAX.midY + (top ? glyphTop : glyphBottom))
    }

    /// Bold digits at three quarters of the badge height (12 pt badge → 9 pt text).
    public static func fontSize(for size: Double) -> Double { size * 0.75 }

    /// A dot is a circle; a count is a circle, or a pill when its text is wider.
    public static func badgeSize(label: BadgeLabel, size: Double, textWidth: Double) -> CGSize {
        switch label {
        case .dot: return CGSize(width: size, height: size)
        case .count: return CGSize(width: max(size, (textWidth).rounded(.up) + size / 2), height: size)
        }
    }

    /// The badge rect, centred on the corner's anchor (a wider pill grows to both sides).
    public static func badgeRectAX(iconAX: CGRect, corner: Corner, badgeSize: CGSize) -> CGRect {
        let a = anchor(iconAX: iconAX, corner: corner)
        return CGRect(x: a.x - badgeSize.width / 2, y: a.y - badgeSize.height / 2,
                      width: badgeSize.width, height: badgeSize.height)
    }

    /// Moves `rect` the least distance needed to lie inside `bounds` (a badge on MenuBadge's own
    /// item must not be cut off by the item's edges).
    public static func clamped(_ rect: CGRect, to bounds: CGRect) -> CGRect {
        var r = rect
        r.origin.x = min(max(r.minX, bounds.minX), bounds.maxX - r.width)
        r.origin.y = min(max(r.minY, bounds.minY), bounds.maxY - r.height)
        return r
    }

    /// AX (top-left origin) to Cocoa screen coordinates (bottom-left origin of the primary screen).
    public static func axToCocoa(_ r: CGRect, primaryScreenMaxY: Double) -> CGRect {
        CGRect(x: r.minX, y: primaryScreenMaxY - r.maxY, width: r.width, height: r.height)
    }

    /// Width of the icon MenuBadge draws in its own item for an app.
    public static let ownItemIconSize: Double = 16

    /// MenuBadge's own item: room for the icon plus a badge on its corner; wider only when a pill
    /// ("999+" at a large size) would not fit, so the item keeps its width as counts change.
    public static func ownItemLength(size: Double, badgeWidth: Double) -> Double {
        max(ownItemIconSize + size + 4, badgeWidth + 4)
    }

    /// Room around a badge in the overlay panel for the 2.2x ripple ring (0.6 of the badge on each
    /// side), the bounce and the shake, per axis so wide pills are not clipped.
    public static func overlayPadding(badgeSize: CGSize) -> CGSize {
        CGSize(width: (badgeSize.width * 0.6).rounded(.up) + 6, height: (badgeSize.height * 0.6).rounded(.up) + 6)
    }
}

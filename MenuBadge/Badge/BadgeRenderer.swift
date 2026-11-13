import AppKit
import BadgeKit

extension NSColor {
    convenience init(_ c: RGBA) {
        self.init(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a)
    }
}

extension RGBA {
    init(_ color: NSColor) {
        let c = color.usingColorSpace(.sRGB) ?? color
        self.init(r: c.redComponent, g: c.greenComponent, b: c.blueComponent, a: c.alphaComponent)
    }
}

/// Draws badge images: a filled circle (dot) or circle/pill with bold text (count).
@MainActor
enum BadgeRenderer {
    private struct Key: Hashable { let label: BadgeLabel; let appearance: BadgeAppearance }
    private static var cache: [Key: NSImage] = [:]

    static func font(size: Double) -> NSFont {
        .systemFont(ofSize: BadgeGeometry.fontSize(for: size), weight: .bold)
    }

    static func textWidth(_ text: String, size: Double) -> Double {
        (text as NSString).size(withAttributes: [.font: font(size: size)]).width
    }

    static func badgeSize(_ label: BadgeLabel, _ a: BadgeAppearance) -> CGSize {
        let width: Double
        if case .count(let text) = label { width = textWidth(text, size: a.size) } else { width = 0 }
        return BadgeGeometry.badgeSize(label: label, size: a.size, textWidth: width)
    }

    static func image(_ label: BadgeLabel, _ a: BadgeAppearance) -> NSImage {
        let key = Key(label: label, appearance: a)
        if let cached = cache[key] { return cached }
        if cache.count > 64 { cache.removeAll() }
        let size = badgeSize(label, a)
        let image = NSImage(size: size, flipped: false) { rect in
            switch label {
            case .dot:
                NSColor(a.dotColor).setFill()
                NSBezierPath(ovalIn: rect).fill()
            case .count(let text):
                NSColor(a.countColor).setFill()
                NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
                let attrs: [NSAttributedString.Key: Any] = [.font: font(size: a.size),
                                                            .foregroundColor: NSColor(a.textColor)]
                let t = (text as NSString).size(withAttributes: attrs)
                // The font's box sits slightly low in the pill; nudge by 1/24 of the height.
                (text as NSString).draw(at: CGPoint(x: rect.midX - t.width / 2,
                                                    y: rect.midY - t.height / 2 + a.size / 24),
                                        withAttributes: attrs)
            }
            return true
        }
        cache[key] = image
        return image
    }
}

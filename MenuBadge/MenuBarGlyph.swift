import AppKit

/// MenuBadge's menu bar icon: the app icon's shape as a template glyph, a rounded square with the
/// badge dot on its bottom-right corner (the "app.badge" symbol has it top-right).
enum MenuBarGlyph {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let square = NSRect(x: 2, y: 3, width: 13, height: 13)
            let outline = NSBezierPath(roundedRect: square.insetBy(dx: 0.75, dy: 0.75), xRadius: 3.5, yRadius: 3.5)
            outline.lineWidth = 1.5
            NSColor.black.setStroke()
            outline.stroke()
            // The dot sits on the corner with a clear gap around it, like the ring on the app icon.
            let centre = CGPoint(x: square.maxX - 1, y: square.minY + 1)
            func circle(_ r: CGFloat) -> NSBezierPath {
                NSBezierPath(ovalIn: NSRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))
            }
            NSGraphicsContext.current?.compositingOperation = .clear
            circle(5).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            NSColor.black.setFill()
            circle(3.5).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "MenuBadge"
        return image
    }()
}

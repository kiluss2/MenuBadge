// Draws docs/images/menubar.png, the README's hero picture: a menu bar (shown 2x) with app icons
// carrying MenuBadge badges, in the default look (red count, blue dot, 19 pt icons, bottom-right).
// Run from the repo root: swift scripts/make-readme-images.swift
import AppKit

let scale: CGFloat = 2                    // points in the picture per menu bar point
let canvas = NSSize(width: 700, height: 110) // in menu bar points
let barHeight: CGFloat = 30
let red = NSColor(srgbRed: 0.93, green: 0.19, blue: 0.20, alpha: 1)
let blue = NSColor(srgbRed: 0.11, green: 0.60, blue: 1.00, alpha: 1)

func appIcon(_ bundleID: String, side: CGFloat) -> NSImage {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return NSImage() }
    let icon = NSWorkspace.shared.icon(forFile: url.path)
    var rect = CGRect(x: 0, y: 0, width: 256, height: 256)
    guard let cg = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return icon }
    // Same trim as MenuBadge: cut the transparent margin so the artwork is `side` points.
    let w = cg.width, h = cg.height
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    let p = ctx.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)
    var minX = w, minY = h, maxX = 0, maxY = 0
    for y in 0..<h { for x in 0..<w where p[(y * w + x) * 4 + 3] >= 128 {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    } }
    let crop = cg.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))!
    return NSImage(cgImage: crop, size: NSSize(width: side, height: side))
}

func symbol(_ name: String, size: CGFloat) -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        .applying(.init(paletteColors: [.white]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(config)!
}

/// A badge centred on the icon's bottom-right corner (6/16 of the icon below its centre).
func badge(_ text: String?, color: NSColor, iconRect: CGRect, size: CGFloat = 12) {
    let font = NSFont.systemFont(ofSize: size * 0.75, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
    let textSize = (text ?? "").size(withAttributes: attrs)
    let width = text == nil ? size : max(size, ceil(textSize.width) + size / 2)
    let centre = CGPoint(x: iconRect.maxX, y: iconRect.midY - iconRect.height * 6 / 16)
    let rect = CGRect(x: centre.x - width / 2, y: centre.y - size / 2, width: width, height: size)
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: size / 2, yRadius: size / 2).fill()
    if let text {
        text.draw(at: CGPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2 + size / 24),
                  withAttributes: attrs)
    }
}

let image = NSImage(size: NSSize(width: canvas.width * scale, height: canvas.height * scale), flipped: false) { _ in
    NSGraphicsContext.current!.cgContext.scaleBy(x: scale, y: scale)
    // Desktop.
    NSGradient(colors: [NSColor(srgbRed: 0.16, green: 0.20, blue: 0.42, alpha: 1),
                        NSColor(srgbRed: 0.42, green: 0.22, blue: 0.50, alpha: 1)])!
        .draw(in: CGRect(origin: .zero, size: canvas), angle: -20)
    // Menu bar.
    let bar = CGRect(x: 0, y: canvas.height - barHeight, width: canvas.width, height: barHeight)
    NSColor(white: 0.08, alpha: 0.55).setFill()
    bar.fill()
    let midY = bar.midY
    let menuFont: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .regular),
                                                   .foregroundColor: NSColor.white]
    let appFont: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .bold),
                                                  .foregroundColor: NSColor.white]
    // Left: Apple menu and the front app's menus.
    let apple = symbol("apple.logo", size: 14)
    apple.draw(in: CGRect(x: 16, y: midY - apple.size.height / 2, width: apple.size.width, height: apple.size.height))
    var left: CGFloat = 16 + apple.size.width + 18
    for (i, title) in ["Finder", "File", "Edit", "View"].enumerated() {
        let attrs = i == 0 ? appFont : menuFont
        title.draw(at: CGPoint(x: left, y: midY - 8), withAttributes: attrs)
        left += title.size(withAttributes: attrs).width + 16
    }
    // Right, laid out from the right edge inwards: clock, status icons, then MenuBadge items.
    var x = canvas.width - 14
    let clock = "Fri 13 Nov  9:41"
    x -= clock.size(withAttributes: menuFont).width
    clock.draw(at: CGPoint(x: x, y: midY - 8), withAttributes: menuFont)
    for name in ["switch.2", "magnifyingglass", "battery.75percent", "wifi"] {
        let s = symbol(name, size: 14)
        x -= 16 + s.size.width
        s.draw(in: CGRect(x: x, y: midY - s.size.height / 2, width: s.size.width, height: s.size.height))
    }
    // Apps with badges, as MenuBadge items (19 pt icons with room for the badge).
    for (id, text, color) in [("com.apple.mail", nil as String?, blue), ("ru.keepcoder.Telegram", "12", red),
                              ("com.tinyspeck.slackmacgap", "3", red)] {
        x -= 16 + 19 + 6
        let rect = CGRect(x: x, y: midY - 9.5, width: 19, height: 19)
        appIcon(id, side: 19).draw(in: rect)
        badge(text, color: color, iconRect: rect)
    }
    // Caption.
    let title: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 22, weight: .bold),
                                                .foregroundColor: NSColor.white]
    let sub: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12.5, weight: .regular),
                                              .foregroundColor: NSColor(white: 1, alpha: 0.8)]
    "Dock badges, in the menu bar".draw(at: CGPoint(x: 16, y: 34), withAttributes: title)
    "Keep the Dock hidden and still see every unread count.".draw(at: CGPoint(x: 16, y: 14), withAttributes: sub)
    return true
}

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "docs/images/menubar.png"))
print("docs/images/menubar.png \(Int(rep.pixelsWide))x\(Int(rep.pixelsHigh))")

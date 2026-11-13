// Draws MenuBadge's app icon into MenuBadge/Assets.xcassets/AppIcon.appiconset.
// Run from the project root: swift scripts/make-appicon.swift
import AppKit

let setDir = URL(fileURLWithPath: "MenuBadge/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: setDir, withIntermediateDirectories: true)

func draw(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(pixels)
    // macOS icon grid: the rounded square fills ~80% of the canvas.
    let body = CGRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    NSColor(srgbRed: 0.13, green: 0.14, blue: 0.17, alpha: 1).setFill()
    NSBezierPath(roundedRect: body, xRadius: s * 0.18, yRadius: s * 0.18).fill()
    // White "app" glyph.
    let glyph = CGRect(x: s * 0.28, y: s * 0.30, width: s * 0.40, height: s * 0.40)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: glyph, xRadius: s * 0.09, yRadius: s * 0.09).fill()
    // Red badge centred on the glyph's bottom-right corner, with a dark ring to separate it.
    let c = CGPoint(x: glyph.maxX, y: glyph.minY)
    let r = s * 0.12
    NSColor(srgbRed: 0.13, green: 0.14, blue: 0.17, alpha: 1).setFill()
    NSBezierPath(ovalIn: CGRect(x: c.x - r * 1.25, y: c.y - r * 1.25, width: r * 2.5, height: r * 2.5)).fill()
    NSColor(srgbRed: 0.93, green: 0.19, blue: 0.20, alpha: 1).setFill()
    NSBezierPath(ovalIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for point in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(point).png" : "icon_\(point)@2x.png"
        try draw(pixels: point * scale).write(to: setDir.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(point)x\(point)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: setDir.appendingPathComponent("Contents.json"))
try #"{"info":{"author":"xcode","version":1}}"#.data(using: .utf8)!
    .write(to: setDir.deletingLastPathComponent().appendingPathComponent("Contents.json"))
print("wrote \(images.count) icons to \(setDir.path)")

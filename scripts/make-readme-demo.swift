// Draws docs/images/demo.gif, the README's animation demo: MenuBadge items on a menu bar (shown 3x),
// each playing one of the badge animations with the same values as BadgeAnimations / AnimationCurves.
// Run from the repo root: swift scripts/make-readme-demo.swift
import AppKit
import ImageIO
import UniformTypeIdentifiers

let scale: CGFloat = 3              // pixels per menu bar point
let fps = 25.0
let loop = 4.0                      // seconds
let slotWidth: CGFloat = 84
let barHeight: CGFloat = 30
let labelHeight: CGFloat = 24
let iconSide: CGFloat = 19
let badgeSize: CGFloat = 12
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

// MARK: Timing, as Core Animation does it

/// Cubic Bézier timing curve through (0,0), (x1,y1), (x2,y2), (1,1), solved for x = t.
func bezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> (Double) -> Double {
    { t in
        func coord(_ a: Double, _ b: Double, _ s: Double) -> Double {
            3 * a * s * (1 - s) * (1 - s) + 3 * b * s * s * (1 - s) + s * s * s
        }
        var lo = 0.0, hi = 1.0
        for _ in 0..<30 { let mid = (lo + hi) / 2; if coord(x1, x2, mid) < t { lo = mid } else { hi = mid } }
        return coord(y1, y2, (lo + hi) / 2)
    }
}
let linear: (Double) -> Double = { $0 }
let easeIn = bezier(0.42, 0, 1, 1)
let easeOut = bezier(0, 0, 0.58, 1)
let easeInOut = bezier(0.42, 0, 0.58, 1)

/// Value of a keyframe animation `elapsed` seconds after it started (nil once it has ended).
func keyframes(_ values: [Double], times: [Double]? = nil, duration: Double,
               timing: [(Double) -> Double]? = nil, overall: (Double) -> Double = linear,
               elapsed: Double) -> Double? {
    guard elapsed >= 0, elapsed <= duration else { return nil }
    let keyTimes = times ?? values.indices.map { Double($0) / Double(values.count - 1) }
    let p = overall(elapsed / duration)
    for i in 0..<(values.count - 1) where p <= keyTimes[i + 1] {
        let span = keyTimes[i + 1] - keyTimes[i]
        let local = span == 0 ? 1 : (p - keyTimes[i]) / span
        let eased = (timing?[i] ?? linear)(local)
        return values[i] + (values[i + 1] - values[i]) * eased
    }
    return values.last
}

/// The latest start at or before `t`, so an animation reads its own elapsed time.
func elapsed(_ t: Double, starts: [Double]) -> Double {
    starts.filter { $0 <= t }.max().map { t - $0 } ?? -1
}

// MARK: The animations (values from BadgeAnimations.swift)

struct BadgeState {
    var dx = 0.0, dy = 0.0, scaleX = 1.0, scaleY = 1.0, opacity = 1.0
    var ringScale = 1.0, ringOpacity = 0.0
}

func blink(_ e: Double, double: Bool) -> Double? {
    // AnimationCurves.blink with the middle of each random range.
    let close = 0.08, open = 0.15, shut = 0.03, closed = 0.1
    var f: [(Double, Double)] = [(0, 1), (close, closed), (close + shut, closed), (close + shut + open, 1)]
    if double {
        let start = f[3].0 + 0.1, c2 = close * 0.9, o2 = open * 0.85
        f += [(start, 1), (start + c2, closed), (start + c2 + shut, closed), (start + c2 + shut + o2, 1)]
    }
    let total = f.last!.0
    let timing = zip(f, f.dropFirst()).map { a, b in b.1 < a.1 ? easeIn : b.1 > a.1 ? easeOut : linear }
    return keyframes(f.map(\.1), times: f.map { $0.0 / total }, duration: total, timing: timing, elapsed: e)
}

func bounce(_ e: Double, height: Double, duration: Double = 0.45) -> Double? {
    keyframes([0, height, 0, height * 0.3, 0], times: [0, 0.35, 0.65, 0.82, 1], duration: duration,
              timing: [easeOut, easeIn, easeOut, easeIn], elapsed: e)
}

func shake(_ e: Double) -> Double? {
    keyframes([0, -3.5, 3.5, -3, 3, -2, 2, -1, 0], duration: 0.6, overall: easeOut, elapsed: e)
}

struct Slot {
    let bundleID: String
    let title: String
    let label: (Double) -> String?          // badge text at time t; "" = dot, nil = no badge
    let color: NSColor
    let state: (Double) -> BadgeState
}

let slots: [Slot] = [
    Slot(bundleID: "com.tinyspeck.slackmacgap", title: "Blink", label: { _ in "3" }, color: red) { t in
        var s = BadgeState()
        if let y = blink(elapsed(t, starts: [0.5]), double: false) ?? blink(elapsed(t, starts: [2.4]), double: true) {
            s.scaleY = y
        }
        return s
    },
    Slot(bundleID: "com.apple.mail", title: "Breathe", label: { _ in "" }, color: blue) { t in
        var s = BadgeState()
        let e = elapsed(t, starts: [0.7, 2.6])
        if let o = keyframes([1, 0.75, 1], duration: 0.3, overall: easeInOut, elapsed: e),
           let k = keyframes([1, 1.12, 1], duration: 0.3, overall: easeInOut, elapsed: e) {
            s.opacity = o; s.scaleX = k; s.scaleY = k
        }
        return s
    },
    Slot(bundleID: "ru.keepcoder.Telegram", title: "Bounce", label: { _ in "12" }, color: red) { t in
        var s = BadgeState()
        s.dy = bounce(elapsed(t, starts: [0.9, 2.8]), height: 2.5) ?? 0
        return s
    },
    Slot(bundleID: "com.apple.MobileSMS", title: "Ripple", label: { _ in "5" }, color: red) { t in
        var s = BadgeState()
        let e = elapsed(t, starts: [1.1, 3.0])
        if let k = keyframes([1, 2.2], duration: 0.8, overall: easeOut, elapsed: e),
           let o = keyframes([0.8, 0], duration: 0.8, overall: easeOut, elapsed: e) {
            s.ringScale = k; s.ringOpacity = o
        }
        return s
    },
    Slot(bundleID: "com.apple.iCal", title: "New: Shake", label: { t in t < 0.6 ? nil : t < 2.2 ? "1" : "2" },
         color: red) { t in
        var s = BadgeState()
        s.dx = shake(elapsed(t, starts: [0.6, 2.2])) ?? 0
        return s
    },
    Slot(bundleID: "com.apple.reminders", title: "New: Bounce", label: { t in t < 1.3 ? nil : "1" },
         color: red) { t in
        var s = BadgeState()
        s.dy = bounce(elapsed(t, starts: [1.3]), height: 5) ?? 0
        return s
    },
]

// MARK: Drawing

let canvas = CGSize(width: slotWidth * CGFloat(slots.count), height: barHeight + labelHeight)
let icons = slots.map { appIcon($0.bundleID, side: iconSide) }
let labelFont: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10.5, weight: .medium),
                                                .foregroundColor: NSColor(white: 1, alpha: 0.75)]

func badgeRect(_ text: String, iconRect: CGRect) -> CGRect {
    let font = NSFont.systemFont(ofSize: badgeSize * 0.75, weight: .bold)
    let w = text.isEmpty ? badgeSize : max(badgeSize, ceil(text.size(withAttributes: [.font: font]).width) + badgeSize / 2)
    let centre = CGPoint(x: iconRect.maxX, y: iconRect.midY - iconRect.height * 6 / 16)
    return CGRect(x: centre.x - w / 2, y: centre.y - badgeSize / 2, width: w, height: badgeSize)
}

func drawFrame(_ t: Double, in ctx: CGContext) {
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    ctx.scaleBy(x: scale, y: scale)
    NSColor(srgbRed: 0.11, green: 0.11, blue: 0.13, alpha: 1).setFill()
    CGRect(origin: .zero, size: canvas).fill()
    NSColor(srgbRed: 0.17, green: 0.17, blue: 0.20, alpha: 1).setFill()
    CGRect(x: 0, y: labelHeight, width: canvas.width, height: barHeight).fill()

    for (i, slot) in slots.enumerated() {
        let midX = slotWidth * (CGFloat(i) + 0.5)
        let midY = labelHeight + barHeight / 2
        let iconRect = CGRect(x: midX - iconSide / 2 - 3, y: midY - iconSide / 2, width: iconSide, height: iconSide)
        icons[i].draw(in: iconRect)
        let title = slot.title as NSString
        let size = title.size(withAttributes: labelFont)
        title.draw(at: CGPoint(x: midX - size.width / 2, y: (labelHeight - size.height) / 2), withAttributes: labelFont)

        guard let text = slot.label(t) else { continue }
        let s = slot.state(t)
        let rect = badgeRect(text, iconRect: iconRect)
        let r = rect.height / 2
        // Ripple ring, under the badge.
        if s.ringOpacity > 0 {
            ctx.saveGState()
            ctx.translateBy(x: rect.midX, y: rect.midY)
            ctx.scaleBy(x: s.ringScale, y: s.ringScale)
            let ring = NSBezierPath(roundedRect: CGRect(x: -rect.width / 2, y: -r, width: rect.width, height: rect.height),
                                    xRadius: r, yRadius: r)
            ring.lineWidth = 1.5
            slot.color.withAlphaComponent(s.ringOpacity).setStroke()
            ring.stroke()
            ctx.restoreGState()
        }
        // The badge, transformed around its centre like the CALayer.
        ctx.saveGState()
        ctx.translateBy(x: rect.midX + s.dx, y: rect.midY + s.dy)
        ctx.scaleBy(x: s.scaleX, y: s.scaleY)
        ctx.setAlpha(s.opacity)
        let local = CGRect(x: -rect.width / 2, y: -r, width: rect.width, height: rect.height)
        slot.color.setFill()
        (text.isEmpty ? NSBezierPath(ovalIn: local) : NSBezierPath(roundedRect: local, xRadius: r, yRadius: r)).fill()
        if !text.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: badgeSize * 0.75, weight: .bold),
                                                        .foregroundColor: NSColor.white]
            let ts = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: -ts.width / 2, y: -ts.height / 2 + badgeSize / 24), withAttributes: attrs)
        }
        ctx.restoreGState()
    }
}

let width = Int(canvas.width * scale), height = Int(canvas.height * scale)
let url = URL(fileURLWithPath: "docs/images/demo.gif")
let frameCount = Int(loop * fps)
let gif = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frameCount, nil)!
CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
let delay = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]] as CFDictionary
for f in 0..<frameCount {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    drawFrame(Double(f) / fps, in: ctx)
    CGImageDestinationAddImage(gif, ctx.makeImage()!, delay)
}
precondition(CGImageDestinationFinalize(gif))
print("docs/images/demo.gif \(width)x\(height), \(frameCount) frames")

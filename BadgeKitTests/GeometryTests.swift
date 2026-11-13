import CoreGraphics
import Testing
import BadgeKit

/// Slack's menu bar item on this Mac, in AX coordinates.
let slackIcon = CGRect(x: 3170, y: 3, width: 34, height: 24)

@Test func todaysBottomRightPosition() {
    let r = BadgeGeometry.badgeRectAX(iconAX: slackIcon, corner: .bottomRight,
                                      badgeSize: CGSize(width: 12, height: 12))
    #expect(r == CGRect(x: 3189, y: 15, width: 12, height: 12)) // centre (3195, 21)
}

@Test func cornersAndSizes() {
    #expect(BadgeGeometry.anchor(iconAX: slackIcon, corner: .topLeft) == CGPoint(x: 3179, y: 8))
    #expect(BadgeGeometry.anchor(iconAX: slackIcon, corner: .topRight) == CGPoint(x: 3195, y: 8))
    #expect(BadgeGeometry.anchor(iconAX: slackIcon, corner: .bottomLeft) == CGPoint(x: 3179, y: 21))
    #expect(BadgeGeometry.badgeSize(label: .dot, size: 10, textWidth: 0) == CGSize(width: 10, height: 10))
    #expect(BadgeGeometry.badgeSize(label: .count("12"), size: 12, textWidth: 9.4) == CGSize(width: 16, height: 12))
    #expect(BadgeGeometry.badgeSize(label: .count("3"), size: 12, textWidth: 5.2) == CGSize(width: 12, height: 12))
    #expect(BadgeGeometry.fontSize(for: 12) == 9)
    #expect(BadgeGeometry.axToCocoa(CGRect(x: 0, y: 3, width: 34, height: 24), primaryScreenMaxY: 1080).minY == 1053)
}

@Test func clampingKeepsTheBadgeInsideItsItem() {
    let bounds = CGRect(x: 0, y: 0, width: 32, height: 22)
    #expect(BadgeGeometry.clamped(CGRect(x: 2, y: -2, width: 12, height: 12), to: bounds)
            == CGRect(x: 2, y: 0, width: 12, height: 12))
    #expect(BadgeGeometry.clamped(CGRect(x: 26, y: 14, width: 12, height: 12), to: bounds)
            == CGRect(x: 20, y: 10, width: 12, height: 12))
    #expect(BadgeGeometry.clamped(CGRect(x: 4, y: 4, width: 12, height: 12), to: bounds)
            == CGRect(x: 4, y: 4, width: 12, height: 12))
}

@Test func ownItemGrowsOnlyForWidePills() {
    #expect(BadgeGeometry.ownItemLength(size: 12, badgeWidth: 12) == 32) // 16 pt icon + badge + 4, as before
    #expect(BadgeGeometry.ownItemLength(size: 16, badgeWidth: 16) == 36)
    #expect(BadgeGeometry.ownItemLength(size: 16, badgeWidth: 38) >= 40)
}

@Test func overlayRoomFitsTheRippleAroundWidePills() {
    #expect(BadgeGeometry.overlayPadding(badgeSize: CGSize(width: 12, height: 12)) == CGSize(width: 14, height: 14))
    let wide = BadgeGeometry.overlayPadding(badgeSize: CGSize(width: 38, height: 16))
    #expect(wide.width >= 38 * 0.6 + 2 && wide.height == 16)
}

@Test func opaqueBoundsTrimTransparentMargins() throws {
    let ctx = try #require(CGContext(data: nil, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 0,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    #expect(ImageTrim.opaqueBounds(of: try #require(ctx.makeImage())) == nil)
    ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 2, y: 0, width: 6, height: 3)) // bottom rows in drawing coordinates
    // Image coordinates (as CGImage.cropping uses) start at the top row.
    #expect(ImageTrim.opaqueBounds(of: try #require(ctx.makeImage())) == CGRect(x: 2, y: 7, width: 6, height: 3))
}

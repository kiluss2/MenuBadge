import AppKit
import BadgeKit
import QuartzCore

/// Draws a badge on top of another app's menu bar icon, in a click-through panel.
@MainActor
final class OverlayPresenter {
    private let panel: NSPanel
    private let badgeLayer = CALayer()
    private let ring = CAShapeLayer()
    private let idle: IdleAnimator

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true // clicks reach the app's icon underneath
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        let host = NSView()
        host.wantsLayer = true
        host.layer?.addSublayer(ring)
        host.layer?.addSublayer(badgeLayer)
        panel.contentView = host
        idle = IdleAnimator(badge: badgeLayer, ring: ring)
    }

    func show(_ label: BadgeLabel, _ a: BadgeAppearance, iconAX: CGRect) {
        guard let primary = NSScreen.screens.first else { return }
        let size = BadgeRenderer.badgeSize(label, a)
        let badgeAX = BadgeGeometry.badgeRectAX(iconAX: iconAX, corner: a.corner, badgeSize: size)
        let badge = BadgeGeometry.axToCocoa(badgeAX, primaryScreenMaxY: primary.frame.maxY)
        // Room for the 2.2x ripple ring, the 5 pt bounce and the 3.5 pt shake without clipping.
        let pad = BadgeGeometry.overlayPadding(badgeSize: size)
        let frame = badge.insetBy(dx: -pad.width, dy: -pad.height)
        if panel.frame != frame { panel.setFrame(frame, display: false) }
        let screen = NSScreen.screens.first { $0.frame.intersects(frame) } ?? primary
        let local = CGRect(x: pad.width, y: pad.height, width: size.width, height: size.height)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        badgeLayer.frame = local
        // Rasterise above the screen scale so swell animations stay sharp, not a stretched bitmap.
        badgeLayer.contentsScale = screen.backingScaleFactor * 1.25
        badgeLayer.minificationFilter = .trilinear
        badgeLayer.contents = BadgeRenderer.image(label, a)
        let color = label == .dot ? a.dotColor : a.countColor
        BadgeAnimations.configureRing(ring, frame: local, color: NSColor(color))
        CATransaction.commit()

        if !panel.isVisible { panel.orderFrontRegardless() }
        idle.start(a.idle)
    }

    func hide() {
        idle.stop()
        if panel.isVisible { panel.orderOut(nil) }
    }

    func playNew(_ effect: NewBadgeEffect) {
        BadgeAnimations.playNew(effect, on: badgeLayer)
    }
}

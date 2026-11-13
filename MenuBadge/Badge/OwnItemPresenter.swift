import AppKit
import BadgeKit
import QuartzCore

/// MenuBadge's own menu bar item for an app without a usable icon: the app's icon with the badge.
@MainActor
final class OwnItemPresenter: NSObject {
    let bundleID: String
    private var item: NSStatusItem?
    private let badgeLayer = CALayer()
    private let ring = CAShapeLayer()
    private lazy var idle = IdleAnimator(badge: badgeLayer, ring: ring)

    init(bundleID: String) {
        self.bundleID = bundleID
    }

    /// `label` nil shows the app icon alone.
    func show(_ label: BadgeLabel?, _ a: BadgeAppearance, appIcon: NSImage) {
        let item = self.item ?? makeItem()
        // Wide enough that a badge on the 16 pt icon's corner is not cut off by the item.
        item.length = 16 + a.size + 4
        guard let button = item.button else { return }
        if button.image !== appIcon { button.image = appIcon }

        guard let label, let host = button.layer else {
            badgeLayer.isHidden = true
            idle.stop()
            return
        }
        let size = BadgeRenderer.badgeSize(label, a)
        let bounds = button.bounds
        // Geometry works top-down like AX; flip when the button's layer is bottom-up.
        var rect = BadgeGeometry.clamped(
            BadgeGeometry.badgeRectAX(iconAX: CGRect(origin: .zero, size: bounds.size), corner: a.corner, badgeSize: size),
            to: CGRect(origin: .zero, size: bounds.size))
        if !button.isFlipped { rect.origin.y = bounds.height - rect.maxY }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if badgeLayer.superlayer !== host {
            host.addSublayer(ring)
            host.addSublayer(badgeLayer)
        }
        badgeLayer.isHidden = false
        badgeLayer.frame = rect
        badgeLayer.contentsScale = (button.window?.backingScaleFactor ?? 2) * 1.25
        badgeLayer.minificationFilter = .trilinear
        badgeLayer.contents = BadgeRenderer.image(label, a)
        let color = label == .dot ? a.dotColor : a.countColor
        BadgeAnimations.configureRing(ring, frame: rect, color: NSColor(color))
        CATransaction.commit()
        idle.start(a.idle)
    }

    func hide() {
        idle.stop()
        badgeLayer.removeFromSuperlayer()
        ring.removeFromSuperlayer()
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    func playNew(_ effect: NewBadgeEffect) {
        BadgeAnimations.playNew(effect, on: badgeLayer)
    }

    private func makeItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.wantsLayer = true
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(openApp)
        self.item = item
        return item
    }

    @objc private func openApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}

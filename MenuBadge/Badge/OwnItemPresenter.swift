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
    /// What the badge layer shows, to redraw the button only when that changes.
    private struct Shown: Equatable {
        let label: BadgeLabel?
        let look: BadgeAppearance
    }
    private var shown: Shown?

    init(bundleID: String) {
        self.bundleID = bundleID
    }

    /// `label` nil shows the app icon alone.
    func show(_ label: BadgeLabel?, _ a: BadgeAppearance, appIcon: NSImage) {
        let item = self.item ?? makeItem()
        let badgeSize = label.map { BadgeRenderer.badgeSize($0, a) }
        // Wide enough that a badge on the 16 pt icon's corner is not cut off by the item.
        let length = BadgeGeometry.ownItemLength(size: a.size, badgeWidth: badgeSize.map { Double($0.width) } ?? 0)
        if item.length != length { item.length = length }
        guard let button = item.button else { return }
        if button.image !== appIcon { button.image = appIcon }
        defer { redrawCopiesOnOtherDisplays(button, Shown(label: label, look: a)) }

        guard let label, let size = badgeSize, let host = button.layer else {
            badgeLayer.isHidden = true
            idle.stop()
            return
        }
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
        shown = nil
    }

    /// The menu bar of every display but the active one shows a copy of this item, and the copy
    /// is only redrawn when the button draws, not when the badge layer on top of it changes; so
    /// the button is redrawn whenever the badge changes. The copies stay still (no animation).
    private func redrawCopiesOnOtherDisplays(_ button: NSStatusBarButton, _ now: Shown) {
        guard now != shown else { return }
        shown = now
        button.needsDisplay = true
    }

    func playNew(_ effect: NewBadgeEffect) {
        BadgeAnimations.playNew(effect, on: badgeLayer)
    }

    private func makeItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Keeps the place the user ⌘-drags the item to, across launches and hide / show.
        item.autosaveName = "MenuBadge.app.\(bundleID)"
        item.isVisible = true
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

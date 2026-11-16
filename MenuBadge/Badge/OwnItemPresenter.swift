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
        let dimmed: Bool
    }
    private var shown: Shown?
    /// The app icon drawn at the layout's icon position, rebuilt when either changes.
    private var paddedIcon: (source: NSImage, layout: BadgeGeometry.OwnItemLayout, image: NSImage)?

    /// The right-click menu (Open, Hide Until New Badge).
    private let contextMenu: () -> NSMenu?

    init(bundleID: String, contextMenu: @escaping () -> NSMenu?) {
        self.bundleID = bundleID
        self.contextMenu = contextMenu
    }

    /// `label` nil shows the app icon alone; `dimmed` greys it ("Dimmed without a badge").
    func show(_ label: BadgeLabel?, _ a: BadgeAppearance, appIcon: NSImage, dimmed: Bool = false) {
        let item = self.item ?? makeItem()
        let badgeSize = label.map { BadgeRenderer.badgeSize($0, a) }
        // The usual padding beside the icon, plus room for the badge on its corner's side.
        let layout = BadgeGeometry.ownItemLayout(size: a.size, badgeWidth: badgeSize.map { Double($0.width) } ?? 0,
                                                 iconSize: a.iconSize, corner: a.corner)
        if item.length != layout.length { item.length = layout.length }
        guard let button = item.button else { return }
        let image = padded(appIcon, layout, iconSize: a.iconSize)
        if button.image !== image { button.image = image }
        let alpha: CGFloat = dimmed ? 0.4 : 1
        if button.alphaValue != alpha { button.alphaValue = alpha }
        defer { redrawCopiesOnOtherDisplays(button, Shown(label: label, look: a, dimmed: dimmed)) }

        guard let label, let size = badgeSize, let host = button.layer else {
            badgeLayer.isHidden = true
            idle.stop()
            return
        }
        let bounds = button.bounds
        // Geometry works top-down like AX; flip when the button's layer is bottom-up. The padded
        // image is centred in the button, so the icon starts at `iconX` of the item's width.
        let left = (bounds.width - layout.length) / 2 + layout.iconX
        let iconAX = CGRect(x: left, y: 0, width: a.iconSize, height: bounds.height)
        var rect = BadgeGeometry.clamped(
            BadgeGeometry.badgeRectAX(iconAX: iconAX, corner: a.corner, badgeSize: size, glyphSize: a.iconSize),
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

    /// `icon` on a canvas as wide as the item, centred in the `iconSize` slot that starts at the
    /// layout's `iconX` (a button centres its image; the icon is off centre to leave the badge room).
    private func padded(_ icon: NSImage, _ layout: BadgeGeometry.OwnItemLayout, iconSize: Double) -> NSImage {
        if let cached = paddedIcon, cached.source === icon, cached.layout == layout { return cached.image }
        let size = NSSize(width: layout.length, height: max(icon.size.height, 1))
        let image = NSImage(size: size, flipped: false) { _ in
            let x = layout.iconX + (iconSize - icon.size.width) / 2
            icon.draw(in: CGRect(x: x, y: 0, width: icon.size.width, height: icon.size.height))
            return true
        }
        image.isTemplate = icon.isTemplate
        paddedIcon = (icon, layout, image)
        return image
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
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.item = item
        return item
    }

    /// Left click opens the app; right click (or Control-click) shows the item's menu.
    @objc private func clicked() {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if wantsMenu, let button = item?.button, let menu = contextMenu() {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        } else {
            openApp()
        }
    }

    private func openApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}

import AppKit
import BadgeKit
import QuartzCore

/// AppKit side of `BadgePreview`: two fake menu bar items, one with "3", one with a dot.
@MainActor
final class PreviewBadgeView: NSView {
    @MainActor private struct Sample {
        let label: BadgeLabel
        let icon = CALayer()
        let ring = CAShapeLayer()
        let badge = CALayer()
        let idle: IdleAnimator

        init(label: BadgeLabel) {
            self.label = label
            idle = IdleAnimator(badge: badge, ring: ring)
        }
    }

    private let samples = [Sample(label: .count("3")), Sample(label: .dot)]
    private var look: BadgeAppearance?

    init(icon: NSImage) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.16, alpha: 1).cgColor
        layer?.cornerRadius = 8
        for sample in samples {
            sample.icon.contents = icon
            sample.icon.contentsGravity = .resizeAspect
            layer?.addSublayer(sample.icon)
            layer?.addSublayer(sample.ring)
            layer?.addSublayer(sample.badge)
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Badge preview")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 44) }

    func apply(_ a: BadgeAppearance) {
        let changed = look != nil && look != a
        look = a
        layoutSamples()
        for sample in samples {
            sample.idle.start(a.idle)
            if changed { BadgeAnimations.playNew(a.onNew, on: sample.badge) }
        }
    }

    override func layout() {
        super.layout()
        layoutSamples()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        layoutSamples()
    }

    private func layoutSamples() {
        guard let a = look else { return }
        let scale = (window?.backingScaleFactor ?? 2) * 1.25
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (i, sample) in samples.enumerated() {
            // A 34x24 "menu bar item" in top-down coordinates, like the real ones.
            let item = CGRect(x: 24 + CGFloat(i) * 60, y: (bounds.height - 24) / 2, width: 34, height: 24)
            let size = BadgeRenderer.badgeSize(sample.label, a)
            var rect = BadgeGeometry.badgeRectAX(iconAX: item, corner: a.corner, badgeSize: size)
            rect.origin.y = bounds.height - rect.maxY
            let iconRect = CGRect(x: item.midX - 8, y: bounds.height - item.midY - 8, width: 16, height: 16)
            sample.icon.frame = iconRect
            sample.badge.frame = rect
            sample.badge.contentsScale = scale
            sample.badge.minificationFilter = .trilinear
            sample.badge.contents = BadgeRenderer.image(sample.label, a)
            let color = sample.label == .dot ? a.dotColor : a.countColor
            BadgeAnimations.configureRing(sample.ring, frame: rect, color: NSColor(color))
        }
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { samples.forEach { $0.idle.stop() } }
    }
}

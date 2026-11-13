import AppKit
import BadgeKit
import QuartzCore

/// Fires one idle animation after a random 2.5-4 s pause, then schedules the next.
/// Only one non-repeating timer exists at a time; nothing animates between firings.
@MainActor
final class IdleAnimator {
    private let badge: CALayer
    private let ring: CAShapeLayer
    private var timer: Timer?
    private(set) var kind: IdleAnimation?

    init(badge: CALayer, ring: CAShapeLayer) {
        self.badge = badge
        self.ring = ring
    }

    /// Starts `kind`; calling again with the same kind while it runs changes nothing. `playNow`
    /// plays it once right away instead of after the first pause (Settings, when it is picked).
    func start(_ kind: IdleAnimation, playNow: Bool = false) {
        guard kind != self.kind else { return }
        stop()
        self.kind = kind
        if playNow { fire() } else { schedule() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        kind = nil
        badge.removeAnimation(forKey: "idle")
        ring.removeAnimation(forKey: "idle")
    }

    private func schedule() {
        guard let kind, kind != .none else { return }
        let t = Timer(timeInterval: .random(in: AnimationCurves.idlePause), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.fire() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func fire() {
        guard let kind else { return }
        switch kind {
        case .blink: BadgeAnimations.blink(badge, double: .random(in: 0..<1) < AnimationCurves.doubleBlinkChance)
        case .breathe: BadgeAnimations.breathe(badge)
        case .bounce: BadgeAnimations.bounce(badge, height: 2.5)
        case .ripple: BadgeAnimations.ripple(ring)
        case .none: return
        }
        schedule()
    }
}

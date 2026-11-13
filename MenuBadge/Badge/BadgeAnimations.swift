import AppKit
import BadgeKit
import QuartzCore

/// One-shot Core Animation presets. None of them repeats: idle ones are fired from a timer
/// (`IdleAnimator`), so nothing animates or recomposites between them.
@MainActor
enum BadgeAnimations {
    /// Eyelid blink from `AnimationCurves.blink`, a little random each time.
    static func blink(_ layer: CALayer, double: Bool) {
        let frames = AnimationCurves.blink(close: .random(in: 0.07...0.09), open: .random(in: 0.13...0.17),
                                           double: double)
        let total = frames.last!.time
        let anim = CAKeyframeAnimation(keyPath: "transform.scale.y")
        anim.values = frames.map(\.value)
        anim.keyTimes = frames.map { NSNumber(value: $0.time / total) }
        // Closing speeds up, opening slows down, holds are linear.
        anim.timingFunctions = zip(frames, frames.dropFirst()).map { from, to in
            CAMediaTimingFunction(name: to.value < from.value ? .easeIn : to.value > from.value ? .easeOut : .linear)
        }
        anim.duration = total
        layer.add(anim, forKey: "idle")
    }

    /// Short, shallow fade + swell (deep fades let the app's logo show through the badge).
    static func breathe(_ layer: CALayer) {
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1, 0.75, 1]
        let swell = CAKeyframeAnimation(keyPath: "transform.scale")
        swell.values = [1, 1.12, 1]
        let group = CAAnimationGroup()
        group.animations = [fade, swell]
        group.duration = 0.3
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(group, forKey: "idle")
    }

    /// A hop of `height` points with a small second hop (layer y points up).
    static func bounce(_ layer: CALayer, height: Double, key: String = "idle") {
        let hop = CAKeyframeAnimation(keyPath: "transform.translation.y")
        hop.values = [0, height, 0, height * 0.3, 0]
        hop.keyTimes = [0, 0.35, 0.65, 0.82, 1]
        hop.timingFunctions = [.init(name: .easeOut), .init(name: .easeIn), .init(name: .easeOut), .init(name: .easeIn)]
        hop.isAdditive = true
        hop.duration = 0.45
        layer.add(hop, forKey: key)
    }

    /// A ring that grows out of the badge and fades; the badge itself stays still and readable.
    static func ripple(_ ring: CAShapeLayer) {
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 1
        grow.toValue = 2.2
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.8
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [grow, fade]
        group.duration = 0.8
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        ring.add(group, forKey: "idle")
    }

    /// Sideways wiggle that dies out, for a new badge.
    static func shake(_ layer: CALayer) {
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -3.5, 3.5, -3, 3, -2, 2, -1, 0]
        shake.duration = 0.6
        shake.isAdditive = true
        shake.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(shake, forKey: "new")
    }

    static func playNew(_ effect: NewBadgeEffect, on layer: CALayer) {
        switch effect {
        case .shake: shake(layer)
        case .bounce: bounce(layer, height: 5, key: "new")
        case .none: break
        }
    }

    /// Fits the (invisible until animated) ripple ring around a badge frame.
    static func configureRing(_ ring: CAShapeLayer, frame: CGRect, color: NSColor) {
        ring.frame = frame
        ring.path = CGPath(roundedRect: CGRect(origin: .zero, size: frame.size),
                           cornerWidth: frame.height / 2, cornerHeight: frame.height / 2, transform: nil)
        ring.fillColor = nil
        ring.strokeColor = color.cgColor
        ring.lineWidth = 1.5
        ring.opacity = 0
    }
}

/// Which animation actually plays: with Reduce Motion on, every effect becomes a soft fade (no
/// movement, no scaling).
public enum MotionPolicy {
    public enum Effect: Equatable, Sendable {
        case blink, breathe, bounce, ripple, shake, fade, none

        public init(_ idle: IdleAnimation) {
            switch idle {
            case .blink: self = .blink
            case .breathe: self = .breathe
            case .bounce: self = .bounce
            case .ripple: self = .ripple
            case .none: self = .none
            }
        }

        public init(_ new: NewBadgeEffect) {
            switch new {
            case .shake: self = .shake
            case .bounce: self = .bounce
            case .none: self = .none
            }
        }
    }

    public static func idle(_ kind: IdleAnimation, reduceMotion: Bool) -> Effect {
        reduce(Effect(kind), reduceMotion)
    }

    public static func onNew(_ effect: NewBadgeEffect, reduceMotion: Bool) -> Effect {
        reduce(Effect(effect), reduceMotion)
    }

    private static func reduce(_ effect: Effect, _ reduceMotion: Bool) -> Effect {
        reduceMotion && effect != .none ? .fade : effect
    }
}

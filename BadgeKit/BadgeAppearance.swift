import Foundation

/// Which corner of the app's menu bar glyph the badge is centred on.
public enum Corner: String, Codable, CaseIterable, Sendable {
    case topLeft, topRight, bottomLeft, bottomRight
}

/// Animation repeated (from a timer, with pauses) while a badge is shown.
public enum IdleAnimation: String, Codable, CaseIterable, Sendable {
    case blink, breathe, bounce, ripple, none
}

/// Effect played once when a badge appears or its count grows.
public enum NewBadgeEffect: String, Codable, CaseIterable, Sendable {
    case shake, bounce, none
}

/// An sRGB colour that can be stored in settings.
public struct RGBA: Codable, Equatable, Hashable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double

    public init(r: Double, g: Double, b: Double, a: Double) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    public static let mentionRed = RGBA(r: 0.93, g: 0.19, b: 0.20, a: 1)
    public static let dotBlue = RGBA(r: 0.11, g: 0.60, b: 1.00, a: 1)
    public static let white = RGBA(r: 1, g: 1, b: 1, a: 1)
}

/// How one app's badge looks and moves.
public struct BadgeAppearance: Codable, Equatable, Hashable, Sendable {
    public var corner: Corner
    public var size: Double
    public var countColor: RGBA
    public var dotColor: RGBA
    public var textColor: RGBA
    public var idle: IdleAnimation
    public var onNew: NewBadgeEffect

    public init(corner: Corner, size: Double, countColor: RGBA, dotColor: RGBA, textColor: RGBA,
                idle: IdleAnimation, onNew: NewBadgeEffect) {
        self.corner = corner; self.size = size; self.countColor = countColor; self.dotColor = dotColor
        self.textColor = textColor; self.idle = idle; self.onNew = onNew
    }

    public static let sizeRange: ClosedRange<Double> = 8...16

    /// The look slack-menubar-badge shipped with.
    public static let standard = BadgeAppearance(
        corner: .bottomRight, size: 12, countColor: .mentionRed, dotColor: .dotBlue, textColor: .white,
        idle: .blink, onNew: .shake)
}

/// Per-app changes on top of the shared default look; nil means "use the default".
public struct AppearanceOverrides: Codable, Equatable, Hashable, Sendable {
    public var corner: Corner?
    public var size: Double?
    public var countColor: RGBA?
    public var dotColor: RGBA?
    public var textColor: RGBA?
    public var idle: IdleAnimation?
    public var onNew: NewBadgeEffect?

    public init() {}

    public var isEmpty: Bool { self == AppearanceOverrides() }

    public func resolved(over base: BadgeAppearance) -> BadgeAppearance {
        let range = BadgeAppearance.sizeRange
        return BadgeAppearance(
            corner: corner ?? base.corner,
            size: min(max(size ?? base.size, range.lowerBound), range.upperBound),
            countColor: countColor ?? base.countColor,
            dotColor: dotColor ?? base.dotColor,
            textColor: textColor ?? base.textColor,
            idle: idle ?? base.idle,
            onNew: onNew ?? base.onNew)
    }
}

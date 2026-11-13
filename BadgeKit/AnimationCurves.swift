/// One point of a keyframe animation: `value` at `time` seconds.
public struct Keyframe: Equatable, Sendable {
    public var time: Double
    public var value: Double

    public init(time: Double, value: Double) { self.time = time; self.value = value }
}

public enum AnimationCurves {
    /// Pause between idle animations: a person blinks every 3-4 s, a little irregularly.
    public static let idlePause: ClosedRange<Double> = 2.5...4
    /// About one blink in four is a double blink.
    public static let doubleBlinkChance = 0.25

    /// Vertical scale of an eyelid blink: close fast to 0.1, stay shut 0.03 s, open more slowly.
    /// A double blink adds a second, quicker one 0.1 s after the first.
    public static func blink(close: Double, open: Double, double: Bool) -> [Keyframe] {
        let shut = 0.03, closed = 0.1
        var frames = [Keyframe(time: 0, value: 1), Keyframe(time: close, value: closed),
                      Keyframe(time: close + shut, value: closed), Keyframe(time: close + shut + open, value: 1)]
        if double {
            let start = frames[3].time + 0.1, close2 = close * 0.9, open2 = open * 0.85
            frames += [Keyframe(time: start, value: 1), Keyframe(time: start + close2, value: closed),
                       Keyframe(time: start + close2 + shut, value: closed),
                       Keyframe(time: start + close2 + shut + open2, value: 1)]
        }
        return frames
    }
}

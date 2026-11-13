/// Whether reading badges is worth it right now: not while the screens sleep, the screen is
/// locked or another user's session is in front, since nobody sees the menu bar then.
public struct PollGate: Equatable, Sendable {
    public enum Reason: Hashable, Sendable { case screensAsleep, screenLocked, sessionInactive }

    private var reasons: Set<Reason> = []

    public init() {}

    public var shouldPoll: Bool { reasons.isEmpty }

    /// Records that `reason` started (`active`) or ended; true when polling just resumed, so the
    /// caller can catch up at once.
    @discardableResult
    public mutating func set(_ reason: Reason, _ active: Bool) -> Bool {
        let wasPolling = shouldPoll
        if active { reasons.insert(reason) } else { reasons.remove(reason) }
        return !wasPolling && shouldPoll
    }
}

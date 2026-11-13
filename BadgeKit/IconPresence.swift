/// Debounces "the app has no menu bar icon": an icon missing for one tick is usually an app that
/// is still launching, quitting or busy, so absence counts only after a few ticks in a row.
public struct IconPresence: Equatable, Sendable {
    public enum State: Equatable, Sendable { case present, pending, absent }

    public static let missesToConfirm = 3
    private var misses = 0

    public init() {}

    public mutating func observe(found: Bool) -> State {
        if found {
            misses = 0
            return .present
        }
        misses += 1
        return misses >= Self.missesToConfirm ? .absent : .pending
    }
}

/// "Hide until new": an app's badge stays hidden until it grows past what was there (a new
/// message), or ends once everything is read.
public struct Snooze: Equatable, Sendable {
    public enum Result: Equatable, Sendable {
        case hidden
        /// Show the badge again; `grew` = it is back because of a new message.
        case ended(grew: Bool)
    }

    /// The badge last seen while hidden: reading some lowers it, so the next message still counts.
    private var reference: BadgeLabel

    public init(at label: BadgeLabel) { reference = label }

    public mutating func observe(_ label: BadgeLabel?) -> Result {
        guard let label else { return .ended(grew: false) }
        if isNewBadge(old: reference, new: label) { return .ended(grew: true) }
        reference = label
        return .hidden
    }
}

/// One app's badge in the compact item.
public struct CompactBadge: Equatable, Sendable {
    public let bundleID: String
    public let label: BadgeLabel

    public init(bundleID: String, label: BadgeLabel) {
        self.bundleID = bundleID
        self.label = label
    }
}

/// What the compact item draws: the first apps with a badge, in sidebar order, and how many more
/// there are ("+N").
public struct CompactLayout: Equatable, Sendable {
    /// Wider than this and the item itself risks being hidden by a full menu bar.
    public static let maxShown = 3

    public let shown: [CompactBadge]
    public let overflow: Int

    public init(_ badges: [CompactBadge]) {
        shown = Array(badges.prefix(Self.maxShown))
        overflow = max(0, badges.count - Self.maxShown)
    }
}

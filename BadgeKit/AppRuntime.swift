/// What MenuBadge currently sees for one app, shown in Settings.
public struct AppRuntime: Equatable, Sendable {
    public enum Location: Equatable, Sendable { case appIcon, ownItem, hidden, compactItem }

    public var isRunning: Bool
    public var location: Location
    /// Whether the running app has a menu bar icon of its own; nil while not known yet.
    public var hasOwnIcon: Bool?

    public init(isRunning: Bool, location: Location, hasOwnIcon: Bool?) {
        self.isRunning = isRunning
        self.location = location
        self.hasOwnIcon = hasOwnIcon
    }
}

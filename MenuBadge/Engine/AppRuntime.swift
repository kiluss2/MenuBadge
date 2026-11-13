/// What MenuBadge currently sees for one app, shown in Settings.
struct AppRuntime: Equatable {
    enum Location: Equatable { case appIcon, ownItem, hidden }

    var isRunning: Bool
    var location: Location
}

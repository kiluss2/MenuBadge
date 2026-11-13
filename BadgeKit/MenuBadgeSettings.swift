import Foundation

/// Where an app's badge goes.
public enum Placement: String, Codable, CaseIterable, Sendable {
    /// On the app's own menu bar icon when it has a usable one, else MenuBadge's item for the app.
    case auto
    /// Prefer the app's icon (falls back to MenuBadge's item when the icon is missing).
    case onAppIcon
    /// Always MenuBadge's own item for the app.
    case ownItem
}

/// When MenuBadge's own item for an app is in the menu bar.
public enum OwnItemVisibility: String, Codable, CaseIterable, Sendable {
    case always, onlyWithBadge
}

/// One app the user added.
public struct AppEntry: Codable, Equatable, Identifiable, Sendable {
    /// Bundle identifier.
    public var id: String
    public var displayName: String
    public var enabled = true
    public var placement = Placement.auto
    public var ownItemVisibility = OwnItemVisibility.always
    public var overrides = AppearanceOverrides()
    /// Whether the app had a usable menu bar icon the last time it was seen running.
    public var lastSeenHadOwnIcon: Bool?
    /// Whether the app has ever put a badge on its Dock tile.
    public var badgeSeen = false

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public struct MenuBadgeSettings: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version = MenuBadgeSettings.currentVersion
    public var defaults = BadgeAppearance.standard
    public var apps: [AppEntry]
    public var showMenuBarIcon = true
    public var openAtLogin = true
    public var paused = false

    public init(apps: [AppEntry]) { self.apps = apps }

    /// Slack on, with today's look, so moving from slack-menubar-badge changes nothing visible.
    public static let firstLaunch = MenuBadgeSettings(
        apps: [AppEntry(id: "com.tinyspeck.slackmacgap", displayName: "Slack")])

    /// The shared default look with the app's own changes applied.
    public func appearance(for bundleID: String) -> BadgeAppearance {
        guard let entry = apps.first(where: { $0.id == bundleID }) else { return defaults }
        return entry.overrides.resolved(over: defaults)
    }
}

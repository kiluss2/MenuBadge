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

/// When MenuBadge's own item for an app is in the menu bar (never once the app has quit).
public enum OwnItemVisibility: String, Codable, CaseIterable, Sendable {
    /// While the app is open, badge or not.
    case always
    case onlyWithBadge
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

    /// Only the bundle id is required; any other field that is missing or unknown keeps its default.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        displayName = c.lenient(String.self, .displayName) ?? id
        enabled = c.lenient(Bool.self, .enabled) ?? true
        placement = c.lenient(Placement.self, .placement) ?? .auto
        ownItemVisibility = c.lenient(OwnItemVisibility.self, .ownItemVisibility) ?? .always
        overrides = c.lenient(AppearanceOverrides.self, .overrides) ?? AppearanceOverrides()
        lastSeenHadOwnIcon = c.lenient(Bool.self, .lastSeenHadOwnIcon)
        badgeSeen = c.lenient(Bool.self, .badgeSeen) ?? false
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
    /// Every badge in MenuBadge's own item instead of per-app placement (for a full menu bar).
    public var compact = false
    /// Look for a newer GitHub release once a day.
    public var checkForUpdates = true

    public init(apps: [AppEntry]) { self.apps = apps }

    /// Settings written by an older or newer MenuBadge keep every value this one understands: a
    /// missing or unknown field keeps its default, and an unreadable app entry is skipped.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.lenient(Int.self, .version) ?? Self.currentVersion
        defaults = c.lenient(BadgeAppearance.self, .defaults) ?? .standard
        apps = try c.decode([Lenient<AppEntry>].self, forKey: .apps).compactMap(\.value)
        showMenuBarIcon = c.lenient(Bool.self, .showMenuBarIcon) ?? true
        openAtLogin = c.lenient(Bool.self, .openAtLogin) ?? true
        paused = c.lenient(Bool.self, .paused) ?? false
        compact = c.lenient(Bool.self, .compact) ?? false
        checkForUpdates = c.lenient(Bool.self, .checkForUpdates) ?? true
    }

    /// Slack on, with today's look, so moving from slack-menubar-badge changes nothing visible.
    public static let firstLaunch = MenuBadgeSettings(
        apps: [AppEntry(id: "com.tinyspeck.slackmacgap", displayName: "Slack")])

    /// The shared default look with the app's own changes applied.
    public func appearance(for bundleID: String) -> BadgeAppearance {
        guard let entry = apps.first(where: { $0.id == bundleID }) else { return defaults }
        return entry.overrides.resolved(over: defaults)
    }
}

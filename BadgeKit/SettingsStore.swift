import Foundation
import Observation

/// Holds the settings and saves every change to UserDefaults as JSON.
@MainActor @Observable
public final class SettingsStore {
    public var settings: MenuBadgeSettings {
        didSet { if settings != oldValue { save() } }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "MenuBadge.settings.v1") {
        self.defaults = defaults
        self.key = key
        settings = Self.load(defaults: defaults, key: key)
    }

    /// Unreadable or unknown-version data starts over with the first-launch settings.
    private static func load(defaults: UserDefaults, key: String) -> MenuBadgeSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(MenuBadgeSettings.self, from: data),
              decoded.version == MenuBadgeSettings.currentVersion else { return .firstLaunch }
        return decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: key) }
    }

    public func addApp(bundleID: String, displayName: String) {
        guard !settings.apps.contains(where: { $0.id == bundleID }) else { return }
        settings.apps.append(AppEntry(id: bundleID, displayName: displayName))
    }

    public func removeApp(bundleID: String) {
        settings.apps.removeAll { $0.id == bundleID }
    }

    /// Changes one app's entry; saves only when something actually changed.
    public func update(_ bundleID: String, _ change: (inout AppEntry) -> Void) {
        guard let i = settings.apps.firstIndex(where: { $0.id == bundleID }) else { return }
        var entry = settings.apps[i]
        change(&entry)
        if entry != settings.apps[i] { settings.apps[i] = entry }
    }
}

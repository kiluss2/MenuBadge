import Foundation
import Observation

/// Where settings are kept: UserDefaults in the app, memory in tests.
public protocol SettingsStorage: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: SettingsStorage {}

/// Holds the settings and saves every change to UserDefaults as JSON.
@MainActor @Observable
public final class SettingsStore {
    public var settings: MenuBadgeSettings {
        didSet { if settings != oldValue { save() } }
    }

    @ObservationIgnored private let defaults: SettingsStorage
    @ObservationIgnored private let key: String

    public init(defaults: SettingsStorage = UserDefaults.standard, key: String = "MenuBadge.settings.v1") {
        self.defaults = defaults
        self.key = key
        settings = Self.load(defaults: defaults, key: key)
    }

    /// Unreadable or unknown-version data starts over with the first-launch settings; the old data
    /// is kept under `<key>.unreadable` so it can still be recovered by hand.
    private static func load(defaults: SettingsStorage, key: String) -> MenuBadgeSettings {
        guard let data = defaults.data(forKey: key) else { return .firstLaunch }
        guard let decoded = try? JSONDecoder().decode(MenuBadgeSettings.self, from: data),
              decoded.version == MenuBadgeSettings.currentVersion else {
            defaults.set(data, forKey: key + ".unreadable")
            return .firstLaunch
        }
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

    /// One app's entry, for bindings (`$store[entry: id]`). Setting nil does nothing.
    public subscript(entry bundleID: String) -> AppEntry? {
        get { settings.apps.first { $0.id == bundleID } }
        set { if let newValue { update(bundleID) { $0 = newValue } } }
    }

    /// A listed app's entry for non-optional bindings (`$store[app: id].enabled`). Reading an app
    /// that is not listed gives a placeholder; writing it changes nothing.
    public subscript(app bundleID: String) -> AppEntry {
        get { self[entry: bundleID] ?? AppEntry(id: bundleID, displayName: bundleID) }
        set { update(bundleID) { $0 = newValue } }
    }

    /// One app's resolved look. Setting it stores the fields that changed as the app's own (even
    /// when equal to Default Look); untouched fields keep following Default Look. ↺ clears a field.
    public subscript(appearanceOf bundleID: String) -> BadgeAppearance {
        get { settings.appearance(for: bundleID) }
        set {
            let old = settings.appearance(for: bundleID)
            update(bundleID) { $0.overrides = $0.overrides.applying(from: old, to: newValue) }
        }
    }

    /// When one app's MenuBadge item shows. A pick is the app's own (even the Default Look value);
    /// ↺ (`visibility = nil`) follows Default Look again.
    public subscript(visibilityOf bundleID: String) -> OwnItemVisibility {
        get { settings.visibility(for: bundleID) }
        set { update(bundleID) { $0.visibility = newValue } }
    }

    /// Changes one app's entry; saves only when something actually changed.
    public func update(_ bundleID: String, _ change: (inout AppEntry) -> Void) {
        guard let i = settings.apps.firstIndex(where: { $0.id == bundleID }) else { return }
        var entry = settings.apps[i]
        change(&entry)
        if entry != settings.apps[i] { settings.apps[i] = entry }
    }
}

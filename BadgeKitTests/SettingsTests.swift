import Foundation
import Testing
import BadgeKit

/// In-memory stand-in for UserDefaults, so tests leave no preference files behind.
private final class MemoryDefaults: SettingsStorage {
    private var values: [String: Any] = [:]
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
}

@Test func standardMatchesTodaysLook() {
    let s = BadgeAppearance.standard
    #expect(s.corner == .bottomRight && s.size == 12 && s.idle == .blink && s.onNew == .shake)
    #expect(s.countColor == RGBA(r: 0.93, g: 0.19, b: 0.20, a: 1))
    #expect(s.dotColor == RGBA(r: 0.11, g: 0.60, b: 1.00, a: 1))
    #expect(s.textColor == .white)
}

@Test func overridesInheritPerField() {
    var o = AppearanceOverrides()
    o.corner = .topLeft
    o.size = 40
    let r = o.resolved(over: .standard)
    #expect(r.corner == .topLeft && r.size == 16 && r.idle == .blink)
    #expect(AppearanceOverrides().isEmpty)
    #expect(!o.isEmpty)
}

@Test func appearanceForUsesDefaultsPlusOverrides() {
    var settings = MenuBadgeSettings.firstLaunch
    settings.defaults.idle = .ripple
    settings.apps[0].overrides.corner = .topRight
    let a = settings.appearance(for: "com.tinyspeck.slackmacgap")
    #expect(a.corner == .topRight && a.idle == .ripple)
    #expect(settings.appearance(for: "unknown.app") == settings.defaults)
}

@MainActor @Test func firstLaunchHasSlackAndPersists() {
    let d = MemoryDefaults()
    let store = SettingsStore(defaults: d)
    #expect(store.settings.apps.map(\.id) == ["com.tinyspeck.slackmacgap"])
    store.addApp(bundleID: "ru.keepcoder.Telegram", displayName: "Telegram")
    store.addApp(bundleID: "ru.keepcoder.Telegram", displayName: "Telegram")
    #expect(SettingsStore(defaults: d).settings.apps.count == 2)
    store.update("ru.keepcoder.Telegram") { $0.placement = .ownItem }
    #expect(SettingsStore(defaults: d).settings.apps[1].placement == .ownItem)
    store.removeApp(bundleID: "ru.keepcoder.Telegram")
    #expect(SettingsStore(defaults: d).settings.apps.count == 1)
}

@MainActor @Test func corruptOrNewerDataFallsBackToFirstLaunch() throws {
    let d = MemoryDefaults()
    d.set(Data("not json".utf8), forKey: "MenuBadge.settings.v1")
    #expect(SettingsStore(defaults: d).settings == .firstLaunch)
    var future = MenuBadgeSettings.firstLaunch
    future.version = 99
    d.set(try JSONEncoder().encode(future), forKey: "MenuBadge.settings.v1")
    #expect(SettingsStore(defaults: d).settings == .firstLaunch)
}

@Test func overridesFromDiffKeepOnlyChangedFields() {
    var look = BadgeAppearance.standard
    look.corner = .topLeft
    look.idle = .ripple
    let o = AppearanceOverrides(diff: look, from: .standard)
    #expect(o.corner == .topLeft && o.idle == .ripple)
    #expect(o.size == nil && o.countColor == nil && o.onNew == nil)
    #expect(AppearanceOverrides(diff: .standard, from: .standard).isEmpty)
}

@MainActor @Test func editingAnAppsLookStoresOnlyDifferences() {
    let d = MemoryDefaults()
    let store = SettingsStore(defaults: d)
    let slack = "com.tinyspeck.slackmacgap"
    store[appearanceOf: slack].size = 14
    #expect(store.settings.apps[0].overrides.size == 14)
    #expect(store.settings.apps[0].overrides.corner == nil)
    store.settings.defaults.corner = .topRight     // not overridden: follows the new default
    #expect(store[appearanceOf: slack].corner == .topRight && store[appearanceOf: slack].size == 14)
    store[entry: slack]?.placement = .ownItem
    #expect(SettingsStore(defaults: d).settings.apps[0].placement == .ownItem)
}

@MainActor @Test func appSubscriptEditsListedAppsAndIgnoresUnknownOnes() {
    let d = MemoryDefaults()
    let store = SettingsStore(defaults: d)
    store[app: "com.tinyspeck.slackmacgap"].enabled = false
    #expect(store.settings.apps[0].enabled == false)
    store[app: "not.listed"].enabled = false
    #expect(store.settings.apps.map(\.id) == ["com.tinyspeck.slackmacgap"])
}

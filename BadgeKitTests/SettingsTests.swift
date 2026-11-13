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

@MainActor @Test func settingsMissingNewerFieldsKeepTheRest() {
    let d = MemoryDefaults()
    let json = #"{"version":1,"apps":[{"id":"ru.keepcoder.Telegram","displayName":"Telegram","placement":"ownItem"}]}"#
    d.set(Data(json.utf8), forKey: "MenuBadge.settings.v1")
    let s = SettingsStore(defaults: d).settings
    #expect(s.apps.map(\.id) == ["ru.keepcoder.Telegram"])
    #expect(s.apps[0].placement == .ownItem && s.apps[0].enabled && s.apps[0].ownItemVisibility == .always)
    #expect(s.defaults == .standard && s.showMenuBarIcon && s.openAtLogin && !s.paused)
}

@MainActor @Test func unknownValueResetsOnlyThatField() {
    let d = MemoryDefaults()
    let json = #"""
    {"version":1,"defaults":{"corner":"middle","size":14},"paused":true,
     "apps":[{"id":"a.b","displayName":"AB","placement":"somewhere","overrides":{"idle":"spin","size":10}}]}
    """#
    d.set(Data(json.utf8), forKey: "MenuBadge.settings.v1")
    let s = SettingsStore(defaults: d).settings
    #expect(s.paused)
    #expect(s.defaults.corner == .bottomRight && s.defaults.size == 14 && s.defaults.idle == .blink)
    #expect(s.apps.map(\.id) == ["a.b"] && s.apps[0].placement == .auto)
    #expect(s.apps[0].overrides.idle == nil && s.apps[0].overrides.size == 10)
}

@MainActor @Test func unreadableSettingsAreKeptAside() {
    let d = MemoryDefaults()
    _ = SettingsStore(defaults: d)
    #expect(d.data(forKey: "MenuBadge.settings.v1.unreadable") == nil)
    d.set(Data("not json".utf8), forKey: "MenuBadge.settings.v1")
    _ = SettingsStore(defaults: d)
    #expect(d.data(forKey: "MenuBadge.settings.v1.unreadable") == Data("not json".utf8))
}

@Test func overridesReportAndClearOneField() {
    var o = AppearanceOverrides()
    o.corner = .topLeft
    o.countColor = .white
    #expect(o.isSet(.corner) && o.isSet(.countColor) && !o.isSet(.size))
    o.clear(.corner)
    #expect(!o.isSet(.corner) && o.isSet(.countColor))
    for field in AppearanceField.allCases {
        var all = AppearanceOverrides(diff: .init(corner: .topLeft, size: 9, countColor: .white, dotColor: .white,
                                                  textColor: .mentionRed, idle: .none, onNew: .none),
                                      from: .standard)
        #expect(all.isSet(field))
        all.clear(field)
        #expect(!all.isSet(field))
    }
}

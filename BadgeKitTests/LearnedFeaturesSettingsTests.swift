import Foundation
import Testing
import BadgeKit

@Test func visibilityFollowsDefaultUnlessSetForTheApp() {
    var s = MenuBadgeSettings(apps: [AppEntry(id: "a", displayName: "A"), AppEntry(id: "b", displayName: "B")])
    #expect(s.visibility(for: "a") == .always)
    s.defaultVisibility = .dimmedWithoutBadge
    s.apps[1].visibility = .onlyWithBadge
    #expect(s.visibility(for: "a") == .dimmedWithoutBadge)
    #expect(s.visibility(for: "b") == .onlyWithBadge)
    #expect(s.visibility(for: "unknown") == .dimmedWithoutBadge)
}

@Test func oldVisibilityValuesMigrate() throws {
    // 1.1.x wrote every app's choice; "always" was the only default, so it now follows Default Look.
    let json = #"{"apps":[{"id":"a","ownItemVisibility":"always"},{"id":"b","ownItemVisibility":"onlyWithBadge"}]}"#
    let s = try JSONDecoder().decode(MenuBadgeSettings.self, from: Data(json.utf8))
    #expect(s.apps[0].visibility == nil)
    #expect(s.apps[1].visibility == .onlyWithBadge)
}

@Test func explicitVisibilitySurvivesARoundTrip() throws {
    var s = MenuBadgeSettings(apps: [AppEntry(id: "a", displayName: "A")])
    s.defaultVisibility = .dimmedWithoutBadge
    s.apps[0].visibility = .always
    let back = try JSONDecoder().decode(MenuBadgeSettings.self, from: JSONEncoder().encode(s))
    #expect(back.apps[0].visibility == .always && back.defaultVisibility == .dimmedWithoutBadge)
}

@Test func alertSettingDefaultsOn() throws {
    let s = try JSONDecoder().decode(MenuBadgeSettings.self, from: Data(#"{"apps":[]}"#.utf8))
    #expect(s.alertWhenMenuBarHidden)
}

@Test func exportAndImportRoundTrip() throws {
    var s = MenuBadgeSettings.firstLaunch
    s.compact = true
    s.defaults.size = 14
    let data = try s.exportData()
    #expect(String(decoding: data, as: UTF8.self).contains("\n")) // readable file
    #expect(try MenuBadgeSettings.imported(from: data) == s)
}

@Test func importRejectsOtherFiles() {
    #expect(throws: (any Error).self) { try MenuBadgeSettings.imported(from: Data("hello".utf8)) }
    #expect(throws: (any Error).self) { try MenuBadgeSettings.imported(from: Data(#"{"name":"x"}"#.utf8)) }
}

@MainActor @Test func aPickedVisibilityStaysWhenDefaultLookChanges() {
    let store = SettingsStore(defaults: TestDefaults())
    let id = store.settings.apps[0].id
    store[visibilityOf: id] = .always // the same as Default Look, but picked for this app
    #expect(store.settings.apps[0].visibility == .always)
    store.settings.defaultVisibility = .onlyWithBadge
    #expect(store[visibilityOf: id] == .always)
    store.update(id) { $0.visibility = nil } // ↺ follows Default Look again
    #expect(store[visibilityOf: id] == .onlyWithBadge)
}

@MainActor @Test func aPickedLookValueStaysWhenDefaultLookChanges() {
    let store = SettingsStore(defaults: TestDefaults())
    let id = store.settings.apps[0].id
    store[appearanceOf: id].size = 15
    store[appearanceOf: id].size = 12 // back to the Default Look value: still the app's own pick
    #expect(store.settings.apps[0].overrides.size == 12)
    #expect(store.settings.apps[0].overrides.corner == nil) // untouched fields keep following
    store.settings.defaults.size = 14
    store.settings.defaults.corner = .topLeft
    #expect(store[appearanceOf: id].size == 12 && store[appearanceOf: id].corner == .topLeft)
}

private final class TestDefaults: SettingsStorage {
    private var values: [String: Any] = [:]
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
}

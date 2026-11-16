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

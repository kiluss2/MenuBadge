import Foundation
import Testing
import BadgeKit

private func release(tag: String, asset: String = "MenuBadge.dmg") -> Data {
    Data("""
    {"tag_name":"\(tag)","html_url":"https://github.com/kiluss2/MenuBadge/releases/tag/\(tag)",
     "assets":[{"name":"\(asset)","browser_download_url":"https://x/\(asset)"}]}
    """.utf8)
}

@Test func versionsCompareNumerically() {
    #expect(AppVersion("1.10.0")! > AppVersion("1.9.0")!)
    #expect(AppVersion("v1.1")! == AppVersion("1.1.0")!)
    #expect(AppVersion("nightly") == nil)
    #expect(AppVersion("") == nil)
}

@Test func newerReleaseFound() throws {
    let update = try ReleaseInfo.newerRelease(json: release(tag: "v1.1.0"), current: "1.0.0")
    #expect(update == AvailableUpdate(version: "1.1.0", dmgURL: URL(string: "https://x/MenuBadge.dmg")!,
                                      pageURL: URL(string: "https://github.com/kiluss2/MenuBadge/releases/tag/v1.1.0")!))
}

@Test func sameOrOlderIsNil() throws {
    #expect(try ReleaseInfo.newerRelease(json: release(tag: "v1.1.0"), current: "1.1.0") == nil)
    #expect(try ReleaseInfo.newerRelease(json: release(tag: "v1.1.0"), current: "1.2") == nil)
}

@Test func missingAssetOrBadTagIsNil() throws {
    #expect(try ReleaseInfo.newerRelease(json: release(tag: "v9.0.0", asset: "Other.zip"), current: "1.0.0") == nil)
    #expect(try ReleaseInfo.newerRelease(json: release(tag: "nightly"), current: "1.0.0") == nil)
}

@Test func garbageThrows() {
    #expect(throws: (any Error).self) { try ReleaseInfo.newerRelease(json: Data("not json".utf8), current: "1.0.0") }
}

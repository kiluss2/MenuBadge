import Foundation

/// A newer MenuBadge release found on GitHub.
public struct AvailableUpdate: Equatable, Sendable {
    /// Without the tag's "v" ("1.1.0").
    public let version: String
    /// The release's `MenuBadge.dmg`.
    public let dmgURL: URL
    /// The release page (notes).
    public let pageURL: URL

    public init(version: String, dmgURL: URL, pageURL: URL) {
        self.version = version; self.dmgURL = dmgURL; self.pageURL = pageURL
    }
}

/// Reads GitHub's "latest release" JSON (`/repos/{owner}/{repo}/releases/latest`).
public enum ReleaseInfo {
    public static let dmgName = "MenuBadge.dmg"

    private struct Release: Decodable {
        let tag_name: String
        let html_url: URL
        let assets: [Asset]
    }
    private struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
    }

    /// The release when it is newer than `current` and carries `MenuBadge.dmg`; throws on JSON
    /// that is not a release.
    public static func newerRelease(json: Data, current: String) throws -> AvailableUpdate? {
        let release = try JSONDecoder().decode(Release.self, from: json)
        guard let latest = AppVersion(release.tag_name), let running = AppVersion(current), latest > running,
              let dmg = release.assets.first(where: { $0.name == dmgName }) else { return nil }
        let tag = release.tag_name
        let version = tag.first == "v" || tag.first == "V" ? String(tag.dropFirst()) : tag
        return AvailableUpdate(version: version, dmgURL: dmg.browser_download_url, pageURL: release.html_url)
    }
}

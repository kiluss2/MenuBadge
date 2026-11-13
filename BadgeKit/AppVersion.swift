/// A dotted version number ("1.10.0", "v1.1"), compared part by part; missing parts count as 0.
public struct AppVersion: Comparable, Sendable {
    private let parts: [Int]

    /// Nil for an empty text or any part that is not a whole number ("nightly", "1.2-beta").
    public init?(_ text: String) {
        var body = Substring(text)
        if body.first == "v" || body.first == "V" { body = body.dropFirst() }
        let parts = body.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        self.parts = parts.map { $0! }
    }

    public static func == (a: AppVersion, b: AppVersion) -> Bool { compare(a, b) == 0 }
    public static func < (a: AppVersion, b: AppVersion) -> Bool { compare(a, b) < 0 }

    private static func compare(_ a: AppVersion, _ b: AppVersion) -> Int {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let x = i < a.parts.count ? a.parts[i] : 0, y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }
}

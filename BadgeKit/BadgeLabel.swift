import Foundation

/// What an app shows on its Dock tile, as MenuBadge draws it.
public enum BadgeLabel: Equatable, Hashable, Sendable {
    /// A number or short text ("3", "99+", "New!"), at most 4 characters; counts above 999 read "999+".
    case count(String)
    /// Slack's "•" for plain unreads.
    case dot

    /// Parses the Dock tile's `AXStatusLabel`. Blank or missing → no badge.
    public static func parse(_ raw: String?) -> BadgeLabel? {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        if text == "•" || text == "●" { return .dot }
        if isOverMaxCount(text) { return .count("999+") }
        return .count(String(text.prefix(4)))
    }

    /// Digits (with any grouping separators and an optional trailing "+") worth more than 999.
    private static func isOverMaxCount(_ text: String) -> Bool {
        let body = text.hasSuffix("+") ? text.dropLast() : Substring(text)
        let separators: Set<Character> = [",", ".", " ", "'", "\u{00A0}", "\u{202F}"]
        guard body.contains(where: \.isASCIIDigit),
              body.allSatisfy({ $0.isASCIIDigit || separators.contains($0) }) else { return false }
        return body.filter(\.isASCIIDigit).drop(while: { $0 == "0" }).count > 3
    }

    /// Leading digits as a number, +1 when followed by "+" ("99+" → 100); nil without digits.
    public var numericValue: Int? {
        guard case .count(let text) = self else { return nil }
        let digits = text.prefix(while: \.isASCIIDigit)
        guard let value = Int(digits) else { return nil }
        return text.dropFirst(digits.count).hasPrefix("+") ? value + 1 : value
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}

/// Whether going from `old` to `new` deserves the "new badge" effect.
public func isNewBadge(old: BadgeLabel?, new: BadgeLabel) -> Bool {
    guard let old else { return true }
    if old == new { return false }
    switch (old, new) {
    case (_, .dot): return false
    case (.dot, .count): return true
    case (.count, .count):
        if let o = old.numericValue, let n = new.numericValue { return n > o }
        return true
    }
}

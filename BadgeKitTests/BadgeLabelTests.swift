import Testing
import BadgeKit

@Test func parsesDotsCountsAndEmpty() {
    #expect(BadgeLabel.parse(nil) == nil)
    #expect(BadgeLabel.parse("  ") == nil)
    #expect(BadgeLabel.parse("•") == .dot)
    #expect(BadgeLabel.parse("●") == .dot)
    #expect(BadgeLabel.parse("3") == .count("3"))
    #expect(BadgeLabel.parse(" New! ") == .count("New!"))
}

@Test func bigCountsAreCappedAt999Plus() {
    #expect(BadgeLabel.parse("999") == .count("999"))
    #expect(BadgeLabel.parse("1000") == .count("999+"))
    #expect(BadgeLabel.parse("1234567") == .count("999+"))
    #expect(BadgeLabel.parse("1,234") == .count("999+"))
    #expect(BadgeLabel.parse("12 345") == .count("999+"))
    #expect(BadgeLabel.parse("1000+") == .count("999+"))
    #expect(BadgeLabel.parse("99+") == .count("99+"))
    #expect(BadgeLabel.parse("Hello") == .count("Hell")) // text is still cut to 4 characters
}

@Test func numericValues() {
    #expect(BadgeLabel.count("12").numericValue == 12)
    #expect(BadgeLabel.count("99+").numericValue == 100)
    #expect(BadgeLabel.count("New!").numericValue == nil)
    #expect(BadgeLabel.dot.numericValue == nil)
}

@Test func newBadgeRules() {
    #expect(isNewBadge(old: nil, new: .dot))
    #expect(!isNewBadge(old: .count("3"), new: .count("3")))
    #expect(isNewBadge(old: .count("3"), new: .count("4")))
    #expect(!isNewBadge(old: .count("4"), new: .count("3")))
    #expect(isNewBadge(old: .count("9"), new: .count("99+")))
    #expect(isNewBadge(old: .dot, new: .count("1")))
    #expect(!isNewBadge(old: .count("1"), new: .dot))
    #expect(isNewBadge(old: .count("New"), new: .count("Hi")))
}

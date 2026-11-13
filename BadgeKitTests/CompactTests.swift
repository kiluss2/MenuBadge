import Testing
import BadgeKit

private func badges(_ n: Int) -> [CompactBadge] {
    (0..<n).map { CompactBadge(bundleID: "app.\($0)", label: .count("\($0 + 1)")) }
}

@Test func compactKeepsOrderAndCaps() {
    let layout = CompactLayout(badges(5))
    #expect(layout.shown.map(\.bundleID) == ["app.0", "app.1", "app.2"])
    #expect(layout.overflow == 2)
    #expect(CompactLayout.maxShown == 3)
}

@Test func compactSmall() {
    let two = CompactLayout(badges(2))
    #expect(two.shown.count == 2 && two.overflow == 0)
    let none = CompactLayout([])
    #expect(none.shown.isEmpty && none.overflow == 0)
}

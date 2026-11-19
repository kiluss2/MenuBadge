import CoreGraphics
import Testing
@testable import BadgeKit

private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
private let colors = CGSize(width: 266, height: 408)

@Test func colorsPanelOpensRightOfTheWindowTopAligned() {
    let window = CGRect(x: 100, y: 100, width: 760, height: 560)
    #expect(PanelPlacement.beside(window, panel: colors, in: screen) == CGRect(x: 868, y: 252, width: 266, height: 408))
}

@Test func colorsPanelGoesLeftWhenTheRightSideHasNoRoom() {
    let window = CGRect(x: 1100, y: 100, width: 760, height: 560)
    #expect(PanelPlacement.beside(window, panel: colors, in: screen).origin == CGPoint(x: 826, y: 252))
}

@Test func colorsPanelStaysOnTheWindowsScreen() {
    // A second screen to the right; the window fills its own screen's height.
    let right = CGRect(x: 1920, y: 0, width: 1920, height: 1055)
    let window = CGRect(x: 1930, y: 600, width: 1880, height: 560)
    let frame = PanelPlacement.beside(window, panel: colors, in: right)
    #expect(right.contains(frame))
}

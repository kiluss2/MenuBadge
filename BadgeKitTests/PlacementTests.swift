import CoreGraphics
import Testing
import BadgeKit

private func input(_ p: Placement = .auto, _ v: OwnItemVisibility = .always, running: Bool = true,
                   iconAX: CGRect? = slackIcon, onScreen: Bool = true, lastOwn: Bool? = true,
                   badge: Bool = true) -> PlacementInput {
    PlacementInput(placement: p, visibility: v, isRunning: running, iconAX: iconAX, iconOnScreen: onScreen,
                   lastSeenHadOwnIcon: lastOwn, hasBadge: badge)
}

@Test func slackQuitShowsNothing() {
    #expect(resolvePlacement(input(running: false, iconAX: nil)) == .none)
}

@Test func appWithoutIconKeepsOwnItemWhenQuit() {
    #expect(resolvePlacement(input(running: false, iconAX: nil, lastOwn: false)) == .ownItem(showBadge: false))
    #expect(resolvePlacement(input(.auto, .onlyWithBadge, running: false, iconAX: nil, lastOwn: false)) == .none)
    #expect(resolvePlacement(input(running: false, iconAX: nil, lastOwn: nil)) == .none)
    #expect(resolvePlacement(input(.ownItem, running: false, iconAX: nil, lastOwn: true)) == .ownItem(showBadge: false))
}

@Test func overlayWhenIconUsable() {
    #expect(resolvePlacement(input()) == .overlay(iconAX: slackIcon))
    #expect(resolvePlacement(input(.onAppIcon)) == .overlay(iconAX: slackIcon))
    #expect(resolvePlacement(input(badge: false)) == .none)
}

@Test func offScreenIconFallsBackToOwnItem() {
    #expect(resolvePlacement(input(onScreen: false)) == .ownItem(showBadge: true))
    #expect(resolvePlacement(input(.onAppIcon, iconAX: nil)) == .ownItem(showBadge: true))
    #expect(resolvePlacement(input(iconAX: nil, badge: false)) == .ownItem(showBadge: false))
}

@Test func forcedOwnItem() {
    #expect(resolvePlacement(input(.ownItem, badge: false)) == .ownItem(showBadge: false))
    #expect(resolvePlacement(input(.ownItem, .onlyWithBadge, badge: false)) == .none)
    #expect(resolvePlacement(input(.ownItem, .onlyWithBadge)) == .ownItem(showBadge: true))
}

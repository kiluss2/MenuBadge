import CoreGraphics
import Testing
import BadgeKit

private func input(_ p: Placement = .auto, _ v: OwnItemVisibility = .always, running: Bool = true,
                   iconAX: CGRect? = slackIcon, onScreen: Bool = true, badge: Bool = true) -> PlacementInput {
    PlacementInput(placement: p, visibility: v, isRunning: running, iconAX: iconAX, iconOnScreen: onScreen,
                   hasBadge: badge)
}

@Test func quitAppNeverKeepsAMenuBadgeItem() {
    // The user's rule: once the app is quit, its MenuBadge item goes too, whatever the settings.
    for placement in Placement.allCases {
        for visibility in OwnItemVisibility.allCases {
            for badge in [true, false] {
                let quit = input(placement, visibility, running: false, iconAX: nil, badge: badge)
                #expect(resolvePlacement(quit) == .none)
            }
        }
    }
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

@Test func missingIconIsConfirmedOnlyAfterThreeTicks() {
    var p = IconPresence()
    #expect(p.observe(found: false) == .pending)
    #expect(p.observe(found: false) == .pending)
    #expect(p.observe(found: false) == .absent)
    #expect(p.observe(found: true) == .present)
    #expect(p.observe(found: false) == .pending)   // one miss after seeing it is not enough
}

@Test func pendingIconShowsNothingUnlessThereIsABadgeToKeep() {
    var i = input(iconAX: nil, badge: false)
    i.iconPending = true
    #expect(resolvePlacement(i) == .none)
    i.hasBadge = true
    #expect(resolvePlacement(i) == .ownItem(showBadge: true))
}

@Test func forceVisibleAlwaysShowsTheBadge() {
    var notRunning = input(running: false, iconAX: nil)
    notRunning.forceVisible = true
    #expect(resolvePlacement(notRunning) == .ownItem(showBadge: true))
    var withIcon = input()
    withIcon.forceVisible = true
    #expect(resolvePlacement(withIcon) == .overlay(iconAX: slackIcon))
}

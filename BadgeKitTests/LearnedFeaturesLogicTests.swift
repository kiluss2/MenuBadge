import Testing
import BadgeKit

@Test func snoozeHoldsUntilTheCountGrows() {
    var snooze = Snooze(at: .count("3"))
    #expect(snooze.observe(.count("3")) == .hidden)
    #expect(snooze.observe(.count("2")) == .hidden)      // read one
    #expect(snooze.observe(.count("3")) == .ended(grew: true)) // a new one after that
}

@Test func snoozeEndsWhenAllIsRead() {
    var snooze = Snooze(at: .count("3"))
    #expect(snooze.observe(nil) == .ended(grew: false))
}

@Test func snoozeOnADotWaitsForACount() {
    var snooze = Snooze(at: .dot)
    #expect(snooze.observe(.dot) == .hidden)
    #expect(snooze.observe(.count("1")) == .ended(grew: true))
}

@Test func reduceMotionKeepsOnlyAFade() {
    for kind in IdleAnimation.allCases {
        #expect(MotionPolicy.idle(kind, reduceMotion: false) == MotionPolicy.Effect(kind))
        #expect(MotionPolicy.idle(kind, reduceMotion: true) == (kind == .none ? .none : .fade))
    }
    #expect(MotionPolicy.onNew(.shake, reduceMotion: false) == .shake)
    #expect(MotionPolicy.onNew(.bounce, reduceMotion: true) == .fade)
    #expect(MotionPolicy.onNew(.none, reduceMotion: true) == .none)
}

@Test func accessNeedsRelaunchWhenTrustedButRefused() {
    #expect(AccessState(trusted: false, apiDisabled: false) == .notGranted)
    #expect(AccessState(trusted: true, apiDisabled: false) == .granted)
    #expect(AccessState(trusted: true, apiDisabled: true) == .needsRelaunch)
    #expect(AccessState(trusted: false, apiDisabled: true) == .notGranted)
}

@Test func menuBarHiddenInFullScreenOrWhenAlwaysHidden() {
    #expect(!MenuBarVisibility.isHidden(frontFullScreen: false, autoHide: false, visibleInFullScreen: false))
    #expect(MenuBarVisibility.isHidden(frontFullScreen: true, autoHide: false, visibleInFullScreen: false))
    #expect(!MenuBarVisibility.isHidden(frontFullScreen: true, autoHide: false, visibleInFullScreen: true))
    #expect(MenuBarVisibility.isHidden(frontFullScreen: false, autoHide: true, visibleInFullScreen: false))
}

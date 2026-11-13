import Testing
import BadgeKit

@Test func firstLaunchAppliesTheStoredSetting() {
    let r = LoginItemSync.atLaunch(stored: true, systemEnabled: false, setUpBefore: false)
    #expect(r.setting == true && r.apply)
}

@Test func laterLaunchesFollowTheSystemState() {
    // The user removed MenuBadge in System Settings › Login Items: keep it removed.
    let r = LoginItemSync.atLaunch(stored: true, systemEnabled: false, setUpBefore: true)
    #expect(r.setting == false && !r.apply)
}

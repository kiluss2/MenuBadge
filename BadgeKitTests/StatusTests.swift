import Testing
import BadgeKit

private func slack(_ placement: Placement = .auto) -> AppEntry {
    var e = AppEntry(id: "com.tinyspeck.slackmacgap", displayName: "Slack")
    e.placement = placement
    e.badgeSeen = true
    return e
}

@Test func statusSaysTheAppHasNoIconOfItsOwn() {
    let noIcon = AppRuntime(isRunning: true, location: .ownItem, hasOwnIcon: false)
    #expect(AppStatusText.describe(entry: slack(), runtime: noIcon) == "Running · MenuBadge item · no icon of its own")
    let chosen = AppRuntime(isRunning: true, location: .ownItem, hasOwnIcon: true)
    #expect(AppStatusText.describe(entry: slack(.ownItem), runtime: chosen) == "Running · MenuBadge item")
    let onIcon = AppRuntime(isRunning: true, location: .appIcon, hasOwnIcon: true)
    #expect(AppStatusText.describe(entry: slack(), runtime: onIcon) == "Running · On its icon")
}

@Test func pausedAndNoPermissionWinOverWhatWasLastSeen() {
    let onIcon = AppRuntime(isRunning: true, location: .appIcon, hasOwnIcon: true)
    #expect(AppStatusText.describe(entry: slack(), runtime: onIcon, paused: true) == "Paused")
    #expect(AppStatusText.describe(entry: slack(), runtime: onIcon, trusted: false) == "Needs Accessibility")
    var off = slack()
    off.enabled = false
    #expect(AppStatusText.describe(entry: off, runtime: onIcon, paused: true) == "Off")
}

@Test func noteExplainsAMissingIconOnlyWhenItMatters() {
    let noIcon = AppRuntime(isRunning: true, location: .ownItem, hasOwnIcon: false)
    let note = AppStatusText.placementNote(entry: slack(), runtime: noIcon)
    #expect(note?.hasPrefix("Slack has no menu bar icon of its own right now") == true)
    #expect(AppStatusText.placementNote(entry: slack(.ownItem), runtime: noIcon) == nil)
    #expect(AppStatusText.placementNote(entry: slack(), runtime: .init(isRunning: true, location: .appIcon, hasOwnIcon: true)) == nil)
    #expect(AppStatusText.placementNote(entry: slack(), runtime: .init(isRunning: false, location: .hidden, hasOwnIcon: nil)) == nil)
}

@Test func statusInCompact() {
    let compact = AppRuntime(isRunning: true, location: .compactItem, hasOwnIcon: false)
    #expect(AppStatusText.describe(entry: slack(), runtime: compact) == "Running · MenuBadge item")
    #expect(AppStatusText.placementNote(entry: slack(), runtime: compact) == nil)
}

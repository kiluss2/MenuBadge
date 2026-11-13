import AppKit
import BadgeKit
import Observation

/// Once a second: for every enabled app, read its Dock badge and menu bar icon, decide where the
/// badge goes and update the overlay / own item.
@MainActor @Observable
final class BadgeEngine {
    /// Whether MenuBadge has Accessibility permission (shown in Settings).
    private(set) var trusted = false
    /// Per app: running or not, and where its badge currently goes.
    private(set) var runtime: [String: AppRuntime] = [:]

    @ObservationIgnored let store: SettingsStore
    @ObservationIgnored private let dock = DockBadgeReader()
    @ObservationIgnored private let extras = MenuExtraReader()
    @ObservationIgnored private var overlays: [String: OverlayPresenter] = [:]
    @ObservationIgnored private var ownItems: [String: OwnItemPresenter] = [:]
    @ObservationIgnored private var lastLabels: [String: BadgeLabel] = [:]
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var demo: DemoRun?
    /// The demo's label for this tick (nil = demo shows no badge right now).
    @ObservationIgnored private var demoLabel: String?
    @ObservationIgnored private var iconPresence: [String: IconPresence] = [:]
    /// MenuBadge's own icon, which carries every badge in compact mode.
    @ObservationIgnored weak var menuBarItem: MenuBarItem?
    /// What the compact item last showed, to redraw only on a change; nil = not in compact mode.
    @ObservationIgnored private var compactShown: (badges: [CompactBadge], appearances: [String: BadgeAppearance])?
    /// No reading while nobody can see the menu bar (screens asleep, locked, other session).
    @ObservationIgnored private var gate = PollGate()

    init(store: SettingsStore) {
        self.store = store
    }

    func start() {
        // A per-element timeout only covers that element, not the menu bar items and Dock tiles read
        // every tick; the system-wide one covers them all, so a hung app can't block MenuBadge.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.5)
        trusted = AXIsProcessTrusted()
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.resetReaders()
                    // Right away rather than on the next tick: a quit app's MenuBadge item goes at once.
                    self?.tick()
                }
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.resetReaders() }
        }
        observeVisibility()
        startTimer()
        tick()
    }

    private func startTimer() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.3
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Stops the timer while the screens sleep, the screen is locked or another user's session
    /// is in front; catches up at once when the menu bar can be seen again.
    private func observeVisibility() {
        let workspace = NSWorkspace.shared.notificationCenter
        let pairs: [(NSNotification.Name, PollGate.Reason, Bool)] = [
            (NSWorkspace.screensDidSleepNotification, .screensAsleep, true),
            (NSWorkspace.screensDidWakeNotification, .screensAsleep, false),
            (NSWorkspace.sessionDidResignActiveNotification, .sessionInactive, true),
            (NSWorkspace.sessionDidBecomeActiveNotification, .sessionInactive, false),
        ]
        for (name, reason, active) in pairs {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setGate(reason, active) }
            }
        }
        let distributed = DistributedNotificationCenter.default()
        for (name, active) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            distributed.addObserver(forName: .init(name), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setGate(.screenLocked, active) }
            }
        }
    }

    private func setGate(_ reason: PollGate.Reason, _ active: Bool) {
        let resumed = gate.set(reason, active)
        if !gate.shouldPoll {
            timer?.invalidate()
            timer = nil
        } else if resumed {
            startTimer()
            resetReaders()
            tick()
        }
    }

    /// Runs the demo on one app's badge; `quitWhenDone` ends MenuBadge afterwards.
    func runDemo(bundleID: String, quitWhenDone: Bool = false) {
        demo?.end()
        demo = DemoRun(bundleID: bundleID, quitWhenDone: quitWhenDone)
        tick()
    }

    func tick() {
        guard gate.shouldPoll else { return }
        let nowTrusted = AXIsProcessTrusted()
        if nowTrusted != trusted {
            trusted = nowTrusted
            resetReaders()
        }
        guard trusted, !store.settings.paused else { hideAll(); return }

        let enabled = store.settings.apps.filter(\.enabled)
        let enabledIDs = Set(enabled.map(\.id))
        advanceDemo(enabledIDs: enabledIDs)
        if store.settings.compact {
            updateCompact(enabled)
            return
        }
        if compactShown != nil {
            compactShown = nil
            menuBarItem?.showCompact(nil, appearances: [:], grewBundleID: nil)
        }
        for id in Set(overlays.keys).union(ownItems.keys) where !enabledIDs.contains(id) { remove(id) }
        for entry in enabled { update(entry) }
    }

    /// Compact mode: only Dock labels are read (no menu bar icon lookups); every badge goes on
    /// MenuBadge's own item, in sidebar order.
    private func updateCompact(_ enabled: [AppEntry]) {
        overlays.values.forEach { $0.hide() }
        ownItems.values.forEach { $0.hide() }
        overlays.removeAll()
        ownItems.removeAll()
        iconPresence.removeAll()

        var badges: [CompactBadge] = []
        var appearances: [String: BadgeAppearance] = [:]
        var grew: String?
        var seen = Set<String>()
        for entry in enabled {
            let id = entry.id
            seen.insert(id)
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: id).first.map { !$0.isTerminated } ?? false
            let inDemo = demo?.bundleID == id
            let label = BadgeLabel.parse(inDemo ? demoLabel : (running ? dock.label(for: id) : nil))
            if let label, !inDemo, !entry.badgeSeen { store.update(id) { $0.badgeSeen = true } }
            let status = AppRuntime(isRunning: running, location: label != nil ? .compactItem : .hidden, hasOwnIcon: nil)
            if runtime[id] != status { runtime[id] = status }
            if let label {
                badges.append(CompactBadge(bundleID: id, label: label))
                appearances[id] = store.settings.appearance(for: id)
                if grew == nil, isNewBadge(old: lastLabels[id], new: label) { grew = id }
            }
            lastLabels[id] = label
        }
        for id in lastLabels.keys where !seen.contains(id) { lastLabels[id] = nil }
        if let shown = compactShown, shown.badges == badges, shown.appearances == appearances, grew == nil { return }
        compactShown = (badges, appearances)
        menuBarItem?.showCompact(CompactLayout(badges), appearances: appearances, grewBundleID: grew)
    }

    /// The menu's app rows in compact mode: every app with a badge, not only the drawn ones.
    func compactRows() -> [MenuBarItem.BadgeRow] {
        guard let shown = compactShown else { return [] }
        return shown.badges.map { badge in
            let name = store.settings.apps.first { $0.id == badge.bundleID }?.displayName ?? badge.bundleID
            let text: String = switch badge.label {
            case .dot: "•"
            case .count(let t): t
            }
            return MenuBarItem.BadgeRow(bundleID: badge.bundleID, name: name, text: text)
        }
    }

    private func update(_ entry: AppEntry) {
        let id = entry.id
        var app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first
        let inDemo = demo?.bundleID == id
        let raw = inDemo ? demoLabel : (app == nil ? nil : dock.label(for: id))
        let label = BadgeLabel.parse(raw)
        let iconAX = app.flatMap { extras.iconFrame(pid: $0.processIdentifier) }
        let iconOnScreen = iconAX.map(isOnScreen) ?? false
        // Re-check after the AX calls: an app that quit meanwhile is not running, and one still
        // launching has not put up its icon yet.
        if app?.isTerminated == true { app = nil }

        var presence = IconPresence.State.pending
        if let app {
            var tracker = iconPresence[id] ?? IconPresence()
            presence = tracker.observe(found: iconAX != nil && iconOnScreen)
            if !app.isFinishedLaunching && presence == .absent { presence = .pending }
            iconPresence[id] = tracker
            store.update(id) { e in
                // Only settled readings are stored, so a launch or quit never flips this.
                if presence != .pending { e.lastSeenHadOwnIcon = presence == .present }
                if label != nil && !inDemo { e.badgeSeen = true }
            }
        } else {
            iconPresence[id] = nil
        }
        let appearance = store.settings.appearance(for: id)
        let current = store.settings.apps.first { $0.id == id } ?? entry
        var input = PlacementInput(
            placement: current.placement, visibility: current.ownItemVisibility, isRunning: app != nil,
            iconAX: iconAX, iconOnScreen: iconOnScreen, hasBadge: label != nil)
        input.iconPending = app != nil && presence == .pending
        input.forceVisible = inDemo
        let decision = resolvePlacement(input)
        let location: AppRuntime.Location = switch decision {
        case .none: .hidden
        case .overlay: .appIcon
        case .ownItem: .ownItem
        }
        let hasOwnIcon: Bool? = app == nil || presence == .pending ? nil : presence == .present
        let status = AppRuntime(isRunning: app != nil, location: location, hasOwnIcon: hasOwnIcon)
        if runtime[id] != status { runtime[id] = status }
        let grew = label.map { isNewBadge(old: lastLabels[id], new: $0) } ?? false
        lastLabels[id] = label

        switch decision {
        case .none:
            overlays[id]?.hide()
            ownItems[id]?.hide()
        case .overlay(let icon):
            guard let label else { return }
            ownItems[id]?.hide()
            let overlay = overlays[id] ?? OverlayPresenter()
            overlays[id] = overlay
            overlay.show(label, appearance, iconAX: icon)
            if grew { overlay.playNew(appearance.onNew) }
        case .ownItem(let showBadge):
            overlays[id]?.hide()
            let item = ownItems[id] ?? OwnItemPresenter(bundleID: id)
            ownItems[id] = item
            item.show(showBadge ? label : nil, appearance, appIcon: AppIconCache.menuBarIcon(for: id, side: appearance.iconSize))
            if grew && showBadge { item.playNew(appearance.onNew) }
        }
    }

    /// Steps the demo once per tick, even when its app is not running; ends it when the app is
    /// switched off or removed (or when it finishes).
    private func advanceDemo(enabledIDs: Set<String>) {
        guard let demo else { return }
        let step: DemoRun.Step = enabledIDs.contains(demo.bundleID) ? demo.current() : .finished
        switch step {
        case .label(let forced):
            demoLabel = forced
        case .finished:
            demo.end()
            self.demo = nil
            demoLabel = nil
            if demo.quitWhenDone { NSApp.terminate(nil) }
        }
    }

    private func isOnScreen(_ axRect: CGRect) -> Bool {
        guard let primary = NSScreen.screens.first else { return false }
        let cocoa = BadgeGeometry.axToCocoa(axRect, primaryScreenMaxY: primary.frame.maxY)
        return NSScreen.screens.contains { $0.frame.intersects(cocoa) }
    }

    private func resetReaders() {
        dock.reset()
        extras.reset()
    }

    private func hideAll() {
        overlays.values.forEach { $0.hide() }
        ownItems.values.forEach { $0.hide() }
        lastLabels.removeAll()
        if compactShown != nil {
            compactShown = nil
            menuBarItem?.showCompact(nil, appearances: [:], grewBundleID: nil)
        }
    }

    private func remove(_ id: String) {
        overlays.removeValue(forKey: id)?.hide()
        ownItems.removeValue(forKey: id)?.hide()
        lastLabels[id] = nil
    }
}

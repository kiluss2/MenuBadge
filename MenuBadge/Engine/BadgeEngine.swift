import AppKit
import BadgeKit
import Observation

/// Once a second: for every enabled app, read its Dock badge and menu bar icon, decide where the
/// badge goes and update the overlay / own item.
@MainActor @Observable
final class BadgeEngine {
    /// Whether MenuBadge has Accessibility permission (shown in Settings).
    private(set) var trusted = false
    /// Accessibility as macOS applies it: on in System Settings is not always in effect yet.
    private(set) var access = AccessState.notGranted
    /// Per app: running or not, and where its badge currently goes.
    private(set) var runtime: [String: AppRuntime] = [:]
    /// Apps whose badge is hidden until a new one comes ("Hide Until New Badge").
    private(set) var snoozedIDs: Set<String> = []

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
    /// Where each running app's menu bar icon was last found, while it is not confirmed gone.
    @ObservationIgnored private var lastIconFrames: [String: CGRect] = [:]
    /// MenuBadge's own icon, which carries every badge in compact mode.
    @ObservationIgnored weak var menuBarItem: MenuBarItem?
    /// What the compact item last showed, to redraw only on a change; nil = not in compact mode.
    @ObservationIgnored private var compactShown: (badges: [CompactBadge], appearances: [String: BadgeAppearance])?
    /// No reading while nobody can see the menu bar (screens asleep, locked, other session).
    @ObservationIgnored private var gate = PollGate()
    @ObservationIgnored private var snoozes: [String: Snooze] = [:]
    /// What each app's Dock tile shows, snoozed or not (menu rows, "Hide Until New Badge").
    @ObservationIgnored private var rawLabels: [String: BadgeLabel] = [:]
    /// The card for badges that grow while the menu bar is hidden.
    @ObservationIgnored private let alert = BadgeAlert()
    /// False until a tick has seen every badge once, so badges already there at launch (or after a
    /// pause) do not pop up as new.
    @ObservationIgnored private var primed = false
    @ObservationIgnored private let dockObserver = DockObserver()

    init(store: SettingsStore) {
        self.store = store
    }

    func start() {
        // A per-element timeout only covers that element, not the menu bar items and Dock tiles read
        // every tick; the system-wide one covers them all, so a hung app can't block MenuBadge.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.5)
        trusted = AXIsProcessTrusted()
        let workspace = NSWorkspace.shared.notificationCenter
        dockObserver.onChange = { [weak self] in
            self?.resetReaders()
            self?.tick()
        }
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.dockObserver.attach() // a restarted Dock has a new process
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
        let nowAccess = AccessState(trusted: trusted, apiDisabled: trusted && dock.apiDisabled)
        if nowAccess != access { access = nowAccess }
        guard trusted, !store.settings.paused else { hideAll(); return }
        dockObserver.attach()
        defer { primed = true }

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
        forget(except: enabledIDs)
    }

    /// The right-click menu of an app's MenuBadge item.
    private func itemMenu(for id: String) -> NSMenu {
        let name = store.settings.apps.first { $0.id == id }?.displayName ?? id
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem("Open \(name)") {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        })
        if snoozes[id] != nil {
            menu.addItem(ClosureMenuItem("Show Badge Now") { [weak self] in self?.unsnooze(id) })
        } else {
            let hide = ClosureMenuItem("Hide Until New Badge") { [weak self] in self?.snooze(id) }
            hide.isEnabled = rawLabels[id] != nil
            menu.addItem(hide)
        }
        return menu
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
            let raw = BadgeLabel.parse(inDemo ? demoLabel : (running ? dock.label(for: id) : nil))
            if raw != nil, !inDemo, !entry.badgeSeen { store.update(id) { $0.badgeSeen = true } }
            let label = inDemo ? raw : visibleLabel(id, raw: raw)
            var status = AppRuntime(isRunning: running, location: label != nil ? .compactItem : .hidden, hasOwnIcon: nil)
            status.snoozed = snoozes[id] != nil
            if runtime[id] != status { runtime[id] = status }
            if let label {
                badges.append(CompactBadge(bundleID: id, label: label))
                appearances[id] = store.settings.appearance(for: id)
                if isNewBadge(old: lastLabels[id], new: label) {
                    if grew == nil { grew = id }
                    if !inDemo { alertIfMenuBarHidden(entry, label) }
                }
            }
            lastLabels[id] = label
        }
        forget(except: seen)
        if let shown = compactShown, shown.badges == badges, shown.appearances == appearances, grew == nil { return }
        compactShown = (badges, appearances)
        menuBarItem?.showCompact(CompactLayout(badges), appearances: appearances, grewBundleID: grew)
    }

    /// The menu's app rows: every enabled app whose Dock tile has a badge, hidden ones included.
    func menuRows() -> [MenuBarItem.BadgeRow] {
        store.settings.apps.filter(\.enabled).compactMap { entry in
            guard let label = rawLabels[entry.id] else { return nil }
            return MenuBarItem.BadgeRow(bundleID: entry.id, name: entry.displayName, text: Self.text(label),
                                        snoozed: snoozes[entry.id] != nil)
        }
    }

    static func text(_ label: BadgeLabel) -> String {
        switch label {
        case .dot: "•"
        case .count(let t): t
        }
    }

    /// Whether the app's Dock tile has a badge now (what "Hide Until New Badge" would hide).
    func hasBadge(_ bundleID: String) -> Bool { rawLabels[bundleID] != nil }

    /// Hides the app's badge until it grows past what it shows now (or everything is read).
    func snooze(_ bundleID: String) {
        guard let label = rawLabels[bundleID] else { return }
        snoozes[bundleID] = Snooze(at: label)
        snoozedIDs.insert(bundleID)
        tick()
    }

    /// Shows a hidden badge again, without the new-badge effect or alert.
    func unsnooze(_ bundleID: String) {
        snoozes[bundleID] = nil
        snoozedIDs.remove(bundleID)
        lastLabels[bundleID] = rawLabels[bundleID]
        tick()
    }

    /// The badge to show for `raw`: nil while the app is snoozed. Ends the snooze when the badge
    /// grows (shown as new) or goes.
    private func visibleLabel(_ id: String, raw: BadgeLabel?) -> BadgeLabel? {
        rawLabels[id] = raw
        guard var snooze = snoozes[id] else { return raw }
        switch snooze.observe(raw) {
        case .hidden:
            snoozes[id] = snooze
            return nil
        case .ended:
            snoozes[id] = nil
            snoozedIDs.remove(id)
            return raw
        }
    }

    /// A card in the corner when a badge grows while the menu bar cannot be seen.
    private func alertIfMenuBarHidden(_ entry: AppEntry, _ label: BadgeLabel) {
        guard primed, store.settings.alertWhenMenuBarHidden, MenuBarWatcher.isHidden() else { return }
        alert.show(AlertRow(id: entry.id, name: entry.displayName, text: Self.text(label)))
    }

    /// Drops per-app state of apps no longer enabled.
    private func forget(except enabled: Set<String>) {
        for id in lastLabels.keys where !enabled.contains(id) { lastLabels[id] = nil }
        for id in rawLabels.keys where !enabled.contains(id) { rawLabels[id] = nil }
        for id in snoozes.keys where !enabled.contains(id) { snoozes[id] = nil }
        snoozedIDs.formIntersection(enabled)
    }

    private func update(_ entry: AppEntry) {
        let id = entry.id
        var app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first
        let inDemo = demo?.bundleID == id
        let raw = BadgeLabel.parse(inDemo ? demoLabel : (app == nil ? nil : dock.label(for: id)))
        let label = inDemo ? raw : visibleLabel(id, raw: raw)
        let iconAX = app.flatMap { extras.iconFrame(pid: $0.processIdentifier) }
        let iconOnScreen = iconAX.map(isOnScreen) ?? false
        // Re-check after the AX calls: an app that quit meanwhile is not running, and one still
        // launching has not put up its icon yet.
        if app?.isTerminated == true { app = nil }

        let iconFound = iconAX != nil && iconOnScreen
        // While Mission Control covers the menu bar the icon is not gone: do not count the miss.
        let covered = app != nil && !iconFound
            && lastIconFrames[id].map { MenuBarCover.covers(CGPoint(x: $0.midX, y: $0.midY)) } == true
        var presence = IconPresence.State.pending
        if let app {
            var tracker = iconPresence[id] ?? IconPresence()
            if !covered { presence = tracker.observe(found: iconFound) }
            if !app.isFinishedLaunching && presence == .absent { presence = .pending }
            iconPresence[id] = tracker
            switch presence {
            case .present: lastIconFrames[id] = iconAX
            case .absent: lastIconFrames[id] = nil
            case .pending: break
            }
            store.update(id) { e in
                // Only settled readings are stored, so a launch or quit never flips this.
                if presence != .pending { e.lastSeenHadOwnIcon = presence == .present }
                if raw != nil && !inDemo { e.badgeSeen = true }
            }
        } else {
            iconPresence[id] = nil
            lastIconFrames[id] = nil
        }
        let appearance = store.settings.appearance(for: id)
        let current = store.settings.apps.first { $0.id == id } ?? entry
        var input = PlacementInput(
            placement: current.placement, visibility: store.settings.visibility(for: id), isRunning: app != nil,
            iconAX: iconAX, iconOnScreen: iconOnScreen, hasBadge: label != nil)
        input.iconPending = app != nil && presence == .pending
        input.iconWasSeen = lastIconFrames[id] != nil
        input.forceVisible = inDemo
        let decision = resolvePlacement(input)
        if decision == .keep { return }
        let location: AppRuntime.Location = switch decision {
        case .none, .keep: .hidden
        case .overlay: .appIcon
        case .ownItem: .ownItem
        }
        let hasOwnIcon: Bool? = app == nil || presence == .pending ? nil : presence == .present
        var status = AppRuntime(isRunning: app != nil, location: location, hasOwnIcon: hasOwnIcon)
        status.snoozed = snoozes[id] != nil
        if runtime[id] != status { runtime[id] = status }
        let grew = label.map { isNewBadge(old: lastLabels[id], new: $0) } ?? false
        lastLabels[id] = label
        if grew, !inDemo, let label { alertIfMenuBarHidden(current, label) }

        switch decision {
        case .keep:
            return
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
            let item = ownItems[id] ?? OwnItemPresenter(bundleID: id) { [weak self] in self?.itemMenu(for: id) }
            ownItems[id] = item
            let shown = showBadge ? label : nil
            let dimmed = shown == nil && store.settings.visibility(for: id) == .dimmedWithoutBadge
            item.show(shown, appearance, appIcon: AppIconCache.menuBarIcon(for: id, side: appearance.iconSize),
                      dimmed: dimmed)
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
        primed = false
        if compactShown != nil {
            compactShown = nil
            menuBarItem?.showCompact(nil, appearances: [:], grewBundleID: nil)
        }
    }

    private func remove(_ id: String) {
        overlays.removeValue(forKey: id)?.hide()
        ownItems.removeValue(forKey: id)?.hide()
        lastLabels[id] = nil
        lastIconFrames[id] = nil
    }
}

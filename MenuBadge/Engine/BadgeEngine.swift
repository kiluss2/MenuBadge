import AppKit
import BadgeKit
import Observation

/// Once a second: for every enabled app, read its Dock badge and menu bar icon, decide where the
/// badge goes and update the overlay / own item.
@MainActor @Observable
final class BadgeEngine {
    /// Whether MenuBadge has Accessibility permission (shown in Settings).
    private(set) var trusted = false

    @ObservationIgnored let store: SettingsStore
    @ObservationIgnored private let dock = DockBadgeReader()
    @ObservationIgnored private let extras = MenuExtraReader()
    @ObservationIgnored private var overlays: [String: OverlayPresenter] = [:]
    @ObservationIgnored private var ownItems: [String: OwnItemPresenter] = [:]
    @ObservationIgnored private var lastLabels: [String: BadgeLabel] = [:]
    @ObservationIgnored private var appIcons: [String: NSImage] = [:]
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var demo: DemoRun?

    init(store: SettingsStore) {
        self.store = store
    }

    func start() {
        trusted = AXIsProcessTrusted()
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.resetReaders() }
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.resetReaders() }
        }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.3
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
    }

    /// Runs the demo on one app's badge; `quitWhenDone` ends MenuBadge afterwards.
    func runDemo(bundleID: String, quitWhenDone: Bool = false) {
        demo?.end()
        demo = DemoRun(bundleID: bundleID, quitWhenDone: quitWhenDone)
        tick()
    }

    func tick() {
        let nowTrusted = AXIsProcessTrusted()
        if nowTrusted != trusted {
            trusted = nowTrusted
            resetReaders()
        }
        guard trusted, !store.settings.paused else { hideAll(); return }

        let enabled = store.settings.apps.filter(\.enabled)
        let enabledIDs = Set(enabled.map(\.id))
        for id in Set(overlays.keys).union(ownItems.keys) where !enabledIDs.contains(id) { remove(id) }
        for entry in enabled { update(entry) }
    }

    private func update(_ entry: AppEntry) {
        let id = entry.id
        let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first
        var raw = app == nil ? nil : dock.label(for: id)
        var fromDock = true
        if let demo, demo.bundleID == id {
            switch demo.current() {
            case .label(let forced): raw = forced; fromDock = false
            case .finished:
                self.demo = nil
                if demo.quitWhenDone { NSApp.terminate(nil) }
            }
        }
        let label = BadgeLabel.parse(raw)
        let iconAX = app.flatMap { extras.iconFrame(pid: $0.processIdentifier) }
        let iconOnScreen = iconAX.map(isOnScreen) ?? false

        if app != nil {
            store.update(id) { e in
                e.lastSeenHadOwnIcon = iconAX != nil && iconOnScreen
                if label != nil && fromDock { e.badgeSeen = true }
            }
        }
        let appearance = store.settings.appearance(for: id)
        let current = store.settings.apps.first { $0.id == id } ?? entry
        let decision = resolvePlacement(PlacementInput(
            placement: current.placement, visibility: current.ownItemVisibility, isRunning: app != nil,
            iconAX: iconAX, iconOnScreen: iconOnScreen, lastSeenHadOwnIcon: current.lastSeenHadOwnIcon,
            hasBadge: label != nil))
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
            item.show(showBadge ? label : nil, appearance, appIcon: appIcon(id))
            if grew && showBadge { item.playNew(appearance.onNew) }
        }
    }

    private func isOnScreen(_ axRect: CGRect) -> Bool {
        guard let primary = NSScreen.screens.first else { return false }
        let cocoa = BadgeGeometry.axToCocoa(axRect, primaryScreenMaxY: primary.frame.maxY)
        return NSScreen.screens.contains { $0.frame.intersects(cocoa) }
    }

    private func appIcon(_ id: String) -> NSImage {
        if let icon = appIcons[id] { return icon }
        let icon: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        }
        icon.size = NSSize(width: 16, height: 16)
        appIcons[id] = icon
        return icon
    }

    private func resetReaders() {
        dock.reset()
        extras.reset()
    }

    private func hideAll() {
        overlays.values.forEach { $0.hide() }
        ownItems.values.forEach { $0.hide() }
        lastLabels.removeAll()
    }

    private func remove(_ id: String) {
        overlays.removeValue(forKey: id)?.hide()
        ownItems.removeValue(forKey: id)?.hide()
        lastLabels[id] = nil
    }
}

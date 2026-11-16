import AppKit
import ApplicationServices

/// Tells when a Dock tile appears or goes (an app pinned, unpinned, launched or quit), so a new
/// tile is read at once rather than at the next rescan. The Dock posts nothing when a badge
/// changes (checked on macOS 27), so badges themselves are still polled.
@MainActor
final class DockObserver {
    var onChange: (() -> Void)?
    private var observer: AXObserver?
    private var pid: pid_t = 0
    private var pending = false

    /// Watches the running Dock; does nothing while it already watches that Dock process.
    func attach() {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return }
        let pid = dock.processIdentifier
        if observer != nil && pid == self.pid { return }
        detach()
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let me = Unmanaged<DockObserver>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { me.changed() }
        }
        var created: AXObserver?
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }
        let app = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXCreatedNotification, kAXUIElementDestroyedNotification] {
            AXObserverAddNotification(created, app, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
        observer = created
        self.pid = pid
    }

    func detach() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        pid = 0
    }

    /// One call per burst: a launch or a Dock restart creates many elements at once.
    private func changed() {
        guard !pending else { return }
        pending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            MainActor.assumeIsolated {
                self?.pending = false
                self?.onChange?()
            }
        }
    }
}

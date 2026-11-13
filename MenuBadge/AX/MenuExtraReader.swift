import AppKit
import ApplicationServices

/// Finds an app's own menu bar icon: the first child of its `AXExtrasMenuBar`.
@MainActor
final class MenuExtraReader {
    private var items: [pid_t: AXUIElement] = [:]

    func reset() { items.removeAll() }

    /// The icon's frame in AX coordinates, or nil when the app has no (visible) menu bar icon.
    func iconFrame(pid: pid_t) -> CGRect? {
        if let item = items[pid] {
            if let frame = AX.frame(item), frame.width > 0 { return frame }
            items[pid] = nil // gone or hidden: look it up again below
        }
        guard let barRef = AX.attr(AX.app(pid: pid), "AXExtrasMenuBar"),
              CFGetTypeID(barRef) == AXUIElementGetTypeID() else { return nil }
        guard let item = AX.children(barRef as! AXUIElement).first,
              let frame = AX.frame(item), frame.width > 0 else { return nil }
        items[pid] = item
        return frame
    }
}

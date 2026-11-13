/// The status lines Settings shows for an app.
public enum AppStatusText {
    /// One line: whether MenuBadge is showing the app's badge and where.
    public static func describe(entry: AppEntry, runtime: AppRuntime?, paused: Bool = false,
                                trusted: Bool = true) -> String {
        // Paused or without permission, MenuBadge shows nothing, whatever it last saw.
        if !entry.enabled { return "Off" }
        if paused { return "Paused" }
        if !trusted { return "Needs Accessibility" }
        var parts: [String] = []
        if let runtime, runtime.isRunning {
            switch runtime.location {
            case .appIcon: parts.append("Running · On its icon")
            case .ownItem:
                parts.append("Running · MenuBadge item")
                if runtime.hasOwnIcon == false && entry.placement != .ownItem { parts.append("no icon of its own") }
            case .compactItem: parts.append("Running · MenuBadge item")
            case .hidden: parts.append(entry.lastSeenHadOwnIcon == false ? "Running · No badge" : "Running")
            }
        } else {
            parts.append("Not running")
        }
        if !entry.badgeSeen { parts.append("No badge seen yet") }
        return parts.joined(separator: " · ")
    }

    /// Why the badge is on a MenuBadge item although the placement prefers the app's own icon.
    public static func placementNote(entry: AppEntry, runtime: AppRuntime?) -> String? {
        guard let runtime, runtime.isRunning, runtime.hasOwnIcon == false, entry.placement != .ownItem,
              runtime.location != .compactItem else { return nil }
        return "\(entry.displayName) has no menu bar icon of its own right now, so its badge is on a MenuBadge item. "
            + "If \(entry.displayName) has a setting to show its menu bar icon, turn it on and the badge moves onto that icon."
    }
}

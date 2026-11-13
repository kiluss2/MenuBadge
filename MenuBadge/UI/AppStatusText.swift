import BadgeKit

/// The one-line status under an app's name in Settings.
enum AppStatusText {
    static func describe(entry: AppEntry, runtime: AppRuntime?) -> String {
        var parts: [String] = []
        if !entry.enabled {
            parts.append("Off")
        } else if let runtime, runtime.isRunning {
            switch runtime.location {
            case .appIcon: parts.append("Running · On its icon")
            case .ownItem: parts.append("Running · MenuBadge item")
            case .hidden: parts.append(entry.lastSeenHadOwnIcon == false ? "Running · No badge" : "Running")
            }
        } else {
            parts.append("Not running")
        }
        if !entry.badgeSeen { parts.append("No badge seen yet") }
        return parts.joined(separator: " · ")
    }
}

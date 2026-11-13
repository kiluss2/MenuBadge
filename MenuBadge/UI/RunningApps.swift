import AppKit

/// Regular (Dock) apps that are running now, as suggestions for the "+" menu.
@MainActor
enum RunningApps {
    struct Candidate: Identifiable {
        let id: String // bundle id
        let name: String
    }

    static func candidates(excluding listed: Set<String>) -> [Candidate] {
        let own = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let id = app.bundleIdentifier, id != own, !listed.contains(id) else { return nil }
                return Candidate(id: id, name: app.localizedName ?? id)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

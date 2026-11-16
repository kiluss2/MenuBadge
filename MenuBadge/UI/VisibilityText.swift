import BadgeKit

/// Names of the MenuBadge item visibility choices, as Settings shows them.
enum VisibilityText {
    static func name(_ visibility: OwnItemVisibility) -> String {
        switch visibility {
        case .always: "While the app is open"
        case .dimmedWithoutBadge: "Dimmed without a badge"
        case .onlyWithBadge: "Only with a badge"
        }
    }
}

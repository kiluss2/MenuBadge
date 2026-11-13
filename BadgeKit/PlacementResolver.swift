import CoreGraphics

/// Where one app's badge is drawn on this tick.
public enum PlacementDecision: Equatable, Sendable {
    case none
    /// On the app's own menu bar icon at this AX rect.
    case overlay(iconAX: CGRect)
    /// On MenuBadge's own item for the app (the app icon, with or without the badge).
    case ownItem(showBadge: Bool)
}

public struct PlacementInput: Sendable {
    public var placement: Placement
    public var visibility: OwnItemVisibility
    public var isRunning: Bool
    public var iconAX: CGRect?
    public var iconOnScreen: Bool
    public var lastSeenHadOwnIcon: Bool?
    public var hasBadge: Bool
    /// The icon was not found on this tick but its absence is not confirmed yet (`IconPresence`).
    public var iconPending = false
    /// Show the badge wherever it can be seen (demo / preview).
    public var forceVisible = false

    public init(placement: Placement, visibility: OwnItemVisibility, isRunning: Bool, iconAX: CGRect?,
                iconOnScreen: Bool, lastSeenHadOwnIcon: Bool?, hasBadge: Bool) {
        self.placement = placement; self.visibility = visibility; self.isRunning = isRunning
        self.iconAX = iconAX; self.iconOnScreen = iconOnScreen
        self.lastSeenHadOwnIcon = lastSeenHadOwnIcon; self.hasBadge = hasBadge
    }
}

public func resolvePlacement(_ input: PlacementInput) -> PlacementDecision {
    let usableIcon = input.iconOnScreen ? input.iconAX : nil
    if input.forceVisible && input.hasBadge {
        if input.isRunning, input.placement != .ownItem, let icon = usableIcon { return .overlay(iconAX: icon) }
        return .ownItem(showBadge: true)
    }
    guard input.isRunning else {
        // Only an app that lives in MenuBadge's item keeps it while closed; an app with its own icon
        // (Slack) shows nothing, so quitting it never makes a MenuBadge item appear.
        let livesInOwnItem = input.placement == .ownItem
            || (input.placement == .auto && input.lastSeenHadOwnIcon == false)
        return input.visibility == .always && livesInOwnItem ? .ownItem(showBadge: false) : .none
    }
    if input.placement != .ownItem, let icon = input.iconAX, input.iconOnScreen {
        return input.hasBadge ? .overlay(iconAX: icon) : .none
    }
    // Icon missing for a tick or two (launching, quitting, busy): keep a badge visible, but do not
    // put up an empty MenuBadge item that would vanish a second later.
    if input.iconPending && input.placement != .ownItem {
        return input.hasBadge ? .ownItem(showBadge: true) : .none
    }
    // Forced own item, or no usable icon: never lose a badge.
    switch input.visibility {
    case .always: return .ownItem(showBadge: input.hasBadge)
    case .onlyWithBadge: return input.hasBadge ? .ownItem(showBadge: true) : .none
    }
}

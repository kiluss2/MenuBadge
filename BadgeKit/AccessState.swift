/// Whether MenuBadge can read other apps. macOS can report the permission as granted while
/// Accessibility calls still fail with `kAXErrorAPIDisabled` until MenuBadge is opened again.
public enum AccessState: Equatable, Sendable {
    case granted, notGranted, needsRelaunch

    public init(trusted: Bool, apiDisabled: Bool) {
        if !trusted { self = .notGranted } else { self = apiDisabled ? .needsRelaunch : .granted }
    }
}

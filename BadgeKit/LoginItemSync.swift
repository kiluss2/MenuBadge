/// How "Open at login" is reconciled with the system at launch.
public enum LoginItemSync {
    /// The first time, MenuBadge applies its stored setting. Afterwards the system's state wins, so
    /// removing MenuBadge in System Settings › Login Items is respected instead of undone.
    public static func atLaunch(stored: Bool, systemEnabled: Bool, setUpBefore: Bool) -> (setting: Bool, apply: Bool) {
        setUpBefore ? (systemEnabled, false) : (stored, true)
    }
}

/// Whether the menu bar (and every badge in it) is out of sight.
public enum MenuBarVisibility {
    /// - frontFullScreen: the frontmost app's focused window is full screen.
    /// - autoHide: "Automatically hide and show the menu bar" is Always.
    /// - visibleInFullScreen: the menu bar is set to stay in full screen.
    public static func isHidden(frontFullScreen: Bool, autoHide: Bool, visibleInFullScreen: Bool) -> Bool {
        autoHide || (frontFullScreen && !visibleInFullScreen)
    }
}

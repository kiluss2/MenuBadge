import CoreGraphics

/// Where a helper panel such as the Colors panel opens: beside a window, on that window's screen.
public enum PanelPlacement {
    /// The panel's frame in Cocoa coordinates: right of `window` with the tops aligned, or left of it
    /// when the right side has no room, kept inside `visible` (the screen's visible frame).
    public static func beside(_ window: CGRect, panel size: CGSize, in visible: CGRect, gap: CGFloat = 8) -> CGRect {
        var x = window.maxX + gap
        if x + size.width > visible.maxX { x = window.minX - gap - size.width }
        x = min(max(x, visible.minX), visible.maxX - size.width)
        let y = min(max(window.maxY - size.height, visible.minY), visible.maxY - size.height)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}

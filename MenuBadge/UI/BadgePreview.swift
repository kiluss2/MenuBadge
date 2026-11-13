import BadgeKit
import SwiftUI

/// A dark strip like the menu bar, with the app's icon carrying a "3" badge and a dot badge,
/// animated with the chosen look.
struct BadgePreview: NSViewRepresentable {
    let appearance: BadgeAppearance
    /// nil shows a generic icon (for the default look).
    let bundleID: String?

    func makeNSView(context: Context) -> PreviewBadgeView {
        PreviewBadgeView(icon: icon)
    }

    func updateNSView(_ view: PreviewBadgeView, context: Context) {
        view.apply(appearance)
    }

    private var icon: NSImage {
        if let bundleID { return AppIconCache.menuBarIcon(for: bundleID) }
        let symbol = NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            .applying(.init(paletteColors: [.white]))
        return symbol.withSymbolConfiguration(config) ?? symbol
    }
}

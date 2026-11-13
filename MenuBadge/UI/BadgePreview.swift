import BadgeKit
import SwiftUI

/// A dark strip like the menu bar, with the app's icon carrying a "3" badge and a dot badge,
/// animated with the chosen look.
struct BadgePreview: NSViewRepresentable {
    let appearance: BadgeAppearance
    /// nil shows a generic icon (for the default look).
    let bundleID: String?
    /// The last animation picked in the editor; each new one plays once.
    var replay: PreviewReplay?

    final class Coordinator {
        var played: UUID?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PreviewBadgeView {
        PreviewBadgeView(icon: icon)
    }

    func updateNSView(_ view: PreviewBadgeView, context: Context) {
        view.apply(appearance)
        if let replay, replay.id != context.coordinator.played {
            context.coordinator.played = replay.id
            view.play(replay.field)
        }
    }

    private var icon: NSImage {
        // Drawn at the largest icon size and scaled down by the preview, so every size is sharp.
        if let bundleID { return AppIconCache.menuBarIcon(for: bundleID, side: BadgeAppearance.iconSizeRange.upperBound) }
        let symbol = NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            .applying(.init(paletteColors: [.white]))
        return symbol.withSymbolConfiguration(config) ?? symbol
    }
}

import SwiftUI

/// ↺ before a value an app sets itself: makes the value follow Default Look again. Its place stays
/// reserved while the value follows Default Look, so the control after it never moves.
struct UseDefaultLookButton: View {
    let title: String
    let isSet: Bool
    let action: () -> Void

    var body: some View {
        Button("Use Default Look for \(title)", systemImage: "arrow.uturn.backward", action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Use the Default Look value")
            .opacity(isSet ? 1 : 0)
            .disabled(!isSet)
            .accessibilityHidden(!isSet)
    }
}

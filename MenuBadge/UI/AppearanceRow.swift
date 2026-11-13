import BadgeKit
import SwiftUI

/// One row of the look editor. On an app's page its label says whether the app sets the value
/// itself or follows Default Look, and a set value has a button to follow Default Look again.
struct AppearanceRow<Control: View>: View {
    let title: String
    let field: AppearanceField
    /// The app's own changes; nil on the Default Look page.
    let overrides: AppearanceOverrides?
    let reset: (AppearanceField) -> Void
    @ContentBuilder let control: Control

    var body: some View {
        LabeledContent {
            HStack {
                control
                if isSet {
                    Button("Use Default Look for \(title)", systemImage: "arrow.uturn.backward", action: resetField)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .help("Use the Default Look value")
                }
            }
        } label: {
            Text(title)
            if let overrides {
                Text(overrides.isSet(field) ? "Set for this app" : "From Default Look")
            }
        }
    }

    private var isSet: Bool { overrides?.isSet(field) == true }

    private func resetField() {
        reset(field)
    }
}

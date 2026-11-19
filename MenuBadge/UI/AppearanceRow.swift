import BadgeKit
import SwiftUI

/// One row of the look editor. On an app's page its label says whether the app sets the value
/// itself or follows Default Look, and ↺ before a set value makes it follow Default Look again.
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
                if overrides != nil {
                    UseDefaultLookButton(title: title, isSet: isSet, action: resetField)
                }
                control
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

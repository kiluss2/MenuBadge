import BadgeKit
import SwiftUI

/// The shared look every app uses until its own look is changed.
struct DefaultLookPane: View {
    @Bindable var store: SettingsStore

    var body: some View {
        Form {
            Section {
                BadgePreview(appearance: store.settings.defaults, bundleID: nil)
                Text("Apps follow this look for every setting you have not changed on the app itself.")
                    .foregroundStyle(.secondary)
            }
            AppearanceEditor(appearance: $store.settings.defaults)
            Section {
                Button("Restore Original Look", action: restore)
                    .disabled(store.settings.defaults == .standard)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Default Look")
    }

    private func restore() {
        store.settings.defaults = .standard
    }
}

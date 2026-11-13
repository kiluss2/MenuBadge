import BadgeKit
import SwiftUI

/// The shared look every app uses until its own look is changed.
struct DefaultLookPane: View {
    @Bindable var store: SettingsStore
    @State private var replay: PreviewReplay?

    var body: some View {
        Form {
            Section {
                BadgePreview(appearance: store.settings.defaults, bundleID: nil, replay: replay)
                Text("Apps follow this look for every setting you have not changed on the app itself.")
                    .foregroundStyle(.secondary)
            }
            AppearanceEditor(appearance: $store.settings.defaults, picked: playInPreview)
            Section {
                Button("Restore Original Look", action: restore)
                    .disabled(store.settings.defaults == .standard)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Default Look")
    }

    private func playInPreview(_ field: AppearanceField) {
        replay = PreviewReplay(field: field)
    }

    private func restore() {
        store.settings.defaults = .standard
    }
}

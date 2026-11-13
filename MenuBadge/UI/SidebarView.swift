import BadgeKit
import SwiftUI

struct SidebarView: View {
    @Bindable var store: SettingsStore
    let engine: BadgeEngine
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("General", systemImage: "gearshape")
                    .tag(SidebarItem.general)
                Label("Default Look", systemImage: "paintpalette")
                    .tag(SidebarItem.defaultLook)
            }
            Section("Apps") {
                ForEach($store.settings.apps) { $entry in
                    AppRow(entry: $entry, runtime: engine.runtime[entry.id])
                        .tag(SidebarItem.app(entry.id))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                AddAppMenu(store: store, selection: $selection)
                Button("Remove App", systemImage: "minus", action: removeSelected)
                    .labelStyle(.iconOnly)
                    .disabled(selectedAppID == nil)
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding()
        }
    }

    private var selectedAppID: String? {
        if case .app(let id) = selection { id } else { nil }
    }

    private func removeSelected() {
        guard let id = selectedAppID else { return }
        store.removeApp(bundleID: id)
        selection = .general
    }
}

import BadgeKit
import SwiftUI

/// The pane for the sidebar selection.
struct DetailView: View {
    let store: SettingsStore
    let engine: BadgeEngine
    @Binding var selection: SidebarItem?

    var body: some View {
        switch selection {
        case .general, nil:
            GeneralPane(store: store, engine: engine)
        case .defaultLook:
            DefaultLookPane(store: store)
        case .app(let id):
            if store[entry: id] != nil {
                AppDetailPane(store: store, engine: engine, bundleID: id)
            } else {
                ContentUnavailableView("App Removed", systemImage: "app.dashed")
            }
        }
    }
}

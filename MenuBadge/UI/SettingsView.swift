import BadgeKit
import SwiftUI

/// Root of the Settings window: sidebar (General, Default Look, apps) and the selected pane.
struct SettingsView: View {
    let store: SettingsStore
    let engine: BadgeEngine
    @State private var selection: SidebarItem?

    init(store: SettingsStore, engine: BadgeEngine, initialSelection: SidebarItem) {
        self.store = store
        self.engine = engine
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, engine: engine, selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            DetailView(store: store, engine: engine, selection: $selection)
        }
        .frame(minWidth: 680, minHeight: 460)
    }
}

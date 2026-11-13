import BadgeKit
import SwiftUI

/// One app: on/off, where its badge goes, and its own look.
struct AppDetailPane: View {
    @Bindable var store: SettingsStore
    let engine: BadgeEngine
    let bundleID: String

    var body: some View {
        if let entry = store[entry: bundleID] {
            Form {
                Section {
                    Toggle("Show badge", isOn: $store[app: bundleID].enabled)
                    LabeledContent("Status", value: AppStatusText.describe(entry: entry,
                                                                           runtime: engine.runtime[bundleID]))
                }
                Section("Where") {
                    Picker("Placement", selection: $store[app: bundleID].placement) {
                        Text("Auto").tag(Placement.auto)
                        Text("On the app's icon").tag(Placement.onAppIcon)
                        Text("MenuBadge item").tag(Placement.ownItem)
                    }
                    Picker("MenuBadge item", selection: $store[app: bundleID].ownItemVisibility) {
                        Text("Always").tag(OwnItemVisibility.always)
                        Text("Only with a badge").tag(OwnItemVisibility.onlyWithBadge)
                    }
                    Text("Auto puts the badge on the app's own menu bar icon, or on a MenuBadge item with the app's icon when it has none.")
                        .foregroundStyle(.secondary)
                }
                Section {
                    BadgePreview(appearance: store[appearanceOf: bundleID], bundleID: bundleID)
                    HStack {
                        Button("Preview All States", systemImage: "play", action: previewAllStates)
                        Button("Reset to Default Look", action: resetLook)
                            .disabled(entry.overrides.isEmpty)
                    }
                }
                AppearanceEditor(appearance: $store[appearanceOf: bundleID])
            }
            .formStyle(.grouped)
            .navigationTitle(entry.displayName)
        }
    }

    private func previewAllStates() {
        engine.runDemo(bundleID: bundleID)
    }

    private func resetLook() {
        store.update(bundleID) { $0.overrides = AppearanceOverrides() }
    }
}

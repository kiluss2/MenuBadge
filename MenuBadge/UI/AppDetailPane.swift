import BadgeKit
import SwiftUI

/// One app: on/off, where its badge goes, and its own look.
struct AppDetailPane: View {
    @Bindable var store: SettingsStore
    let engine: BadgeEngine
    let bundleID: String
    @State private var replay: PreviewReplay?

    var body: some View {
        if let entry = store[entry: bundleID] {
            Form {
                Section {
                    Toggle("Show badge", isOn: $store[app: bundleID].enabled)
                    LabeledContent("Status", value: AppStatusText.describe(
                        entry: entry, runtime: engine.runtime[bundleID], paused: store.settings.paused,
                        trusted: engine.trusted))
                }
                Section("Where") {
                    Picker("Placement", selection: $store[app: bundleID].placement) {
                        Text("Auto").tag(Placement.auto)
                        Text("On the app's icon").tag(Placement.onAppIcon)
                        Text("MenuBadge item").tag(Placement.ownItem)
                    }
                    Picker("MenuBadge item", selection: $store[app: bundleID].ownItemVisibility) {
                        Text("While the app is open").tag(OwnItemVisibility.always)
                        Text("Only with a badge").tag(OwnItemVisibility.onlyWithBadge)
                    }
                    Text("Auto puts the badge on the app's own menu bar icon, or on a MenuBadge item with the app's icon when it has none. A MenuBadge item goes away when its app quits.")
                        .foregroundStyle(.secondary)
                    if let note = AppStatusText.placementNote(entry: entry, runtime: engine.runtime[bundleID]) {
                        Label(note, systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    BadgePreview(appearance: store[appearanceOf: bundleID], bundleID: bundleID, replay: replay)
                    HStack {
                        Button("Preview All States", systemImage: "play", action: previewAllStates)
                            .disabled(!entry.enabled)
                            .help(entry.enabled ? "Shows every badge state in the menu bar"
                                                : "Turn on Show badge to preview")
                        Button("Reset to Default Look", action: resetLook)
                            .disabled(entry.overrides.isEmpty)
                    }
                }
                AppearanceEditor(appearance: $store[appearanceOf: bundleID], overrides: entry.overrides,
                                 reset: resetField, picked: playInPreview)
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

    private func playInPreview(_ field: AppearanceField) {
        replay = PreviewReplay(field: field)
    }

    private func resetField(_ field: AppearanceField) {
        store.update(bundleID) { $0.overrides.clear(field) }
    }
}

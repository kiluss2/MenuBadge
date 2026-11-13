import AppKit
import BadgeKit
import SwiftUI

struct GeneralPane: View {
    @Bindable var store: SettingsStore
    let engine: BadgeEngine

    var body: some View {
        Form {
            Section("Permission") {
                LabeledContent("Accessibility") {
                    Label(engine.trusted ? "Granted" : "Not granted",
                          systemImage: engine.trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(engine.trusted ? .green : .orange)
                }
                if !engine.trusted {
                    Text("MenuBadge reads Dock badges and menu bar icons through Accessibility. Turn MenuBadge on in Privacy & Security › Accessibility; badges start right away.")
                        .foregroundStyle(.secondary)
                    Button("Open Privacy Settings", action: openPrivacySettings)
                }
            }
            Section("MenuBadge") {
                Toggle(isOn: $store.settings.showMenuBarIcon) {
                    Text("Show MenuBadge in menu bar")
                    if store.settings.compact {
                        Text("Always shown in compact mode")
                    }
                }
                .disabled(store.settings.compact)
                Toggle(isOn: $store.settings.compact) {
                    Text("Gather badges in one item")
                    Text("For a full menu bar: every badge goes on MenuBadge's icon, so none is hidden with the icons macOS cannot fit. ⌘-drag the icon to keep it near the clock.")
                }
                Toggle("Open at login", isOn: $store.settings.openAtLogin)
                Toggle("Pause all badges", isOn: $store.settings.paused)
            }
            Section {
                Text("Hidden from the menu bar, MenuBadge still opens its settings when you open the app again from Spotlight, Launchpad or Finder.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }

    private func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else { return }
        NSWorkspace.shared.open(url)
    }
}

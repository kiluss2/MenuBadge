import AppKit
import BadgeKit
import SwiftUI

struct GeneralPane: View {
    @Bindable var store: SettingsStore
    let engine: BadgeEngine
    @Environment(UpdateChecker.self) private var updater

    var body: some View {
        Form {
            Section("Permission") {
                LabeledContent("Accessibility") {
                    Label(accessText, systemImage: engine.access == .granted ? "checkmark.circle.fill"
                                                                            : "exclamationmark.triangle.fill")
                        .foregroundStyle(engine.access == .granted ? .green : .orange)
                }
                if engine.access == .needsRelaunch {
                    Text("MenuBadge is on in Privacy & Security › Accessibility, but macOS has not applied it yet. Opening MenuBadge again applies it.")
                        .foregroundStyle(.secondary)
                    Button("Relaunch MenuBadge", action: relaunch)
                } else if !engine.trusted {
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
            Section("Alerts") {
                Toggle(isOn: $store.settings.alertWhenMenuBarHidden) {
                    Text("Show a card when the menu bar is hidden")
                    Text("While a full-screen app hides the menu bar, a badge that grows also shows in a card in the screen's corner for a few seconds. Click it to open the app.")
                }
            }
            Section("Settings File") {
                HStack {
                    Button("Export…", action: exportSettings)
                    Button("Import…", action: importSettings)
                }
                Text("Saves every setting to a file, or replaces them with one, to set up another Mac the same way.")
                    .foregroundStyle(.secondary)
            }
            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $store.settings.checkForUpdates)
                if let update = updater.available {
                    LabeledContent("MenuBadge \(update.version) is available") {
                        Button("Update", action: updater.install)
                    }
                    Link("Release notes", destination: update.pageURL)
                } else {
                    LabeledContent(updateStatus) {
                        Button("Check for Updates…") {
                            Task { await updater.checkNow(manual: true) }
                        }
                        .disabled(updater.status == .checking)
                    }
                }
            }
            Section {
                Text("Hidden from the menu bar, MenuBadge still opens its settings when you open the app again from Spotlight, Launchpad or Finder.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }

    private var updateStatus: String {
        switch updater.status {
        case .idle: "Version \(UpdateChecker.currentVersion)"
        case .checking: "Checking…"
        case .upToDate: "MenuBadge is up to date"
        case .failed: "Could not check for updates"
        }
    }

    private var accessText: String {
        switch engine.access {
        case .granted: "Granted"
        case .notGranted: "Not granted"
        case .needsRelaunch: "Needs a relaunch"
        }
    }

    private func relaunch() {
        if DetachedProcess.relaunchSoon() { NSApp.terminate(nil) }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MenuBadge Settings.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.settings.exportData().write(to: url, options: .atomic)
        } catch {
            showError("Could not save the settings file.", error)
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let imported: MenuBadgeSettings
        do {
            imported = try MenuBadgeSettings.imported(from: Data(contentsOf: url))
        } catch {
            showError("This file is not MenuBadge settings.", error)
            return
        }
        let confirm = NSAlert()
        confirm.messageText = "Replace your MenuBadge settings?"
        confirm.informativeText = "Your apps, looks and options are replaced by the ones in \"\(url.lastPathComponent)\" (\(imported.apps.count) apps)."
        confirm.addButton(withTitle: "Replace")
        confirm.addButton(withTitle: "Cancel")
        if confirm.runModal() == .alertFirstButtonReturn { store.settings = imported }
    }

    private func showError(_ message: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else { return }
        NSWorkspace.shared.open(url)
    }
}

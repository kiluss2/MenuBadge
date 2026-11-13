import AppKit
import BadgeKit
import SwiftUI
import UniformTypeIdentifiers

/// "+" menu: running apps not yet listed, then a file picker on /Applications.
struct AddAppMenu: View {
    let store: SettingsStore
    @Binding var selection: SidebarItem?

    var body: some View {
        Menu("Add App", systemImage: "plus") {
            ForEach(RunningApps.candidates(excluding: Set(store.settings.apps.map(\.id)))) { app in
                Button {
                    add(app)
                } label: {
                    Label {
                        Text(app.name)
                    } icon: {
                        Image(nsImage: AppIconCache.menuIcon(for: app.id))
                    }
                    // The menu's own icon-only style would otherwise hide the app icons.
                    .labelStyle(.titleAndIcon)
                }
            }
            Divider()
            Button("Choose from Applications…", action: chooseFromApplications)
        }
        .labelStyle(.iconOnly)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func add(_ app: RunningApps.Candidate) {
        store.addApp(bundleID: app.id, displayName: app.name)
        selection = .app(app.id)
    }

    private func chooseFromApplications() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url,
              let id = Bundle(url: url)?.bundleIdentifier else { return }
        add(RunningApps.Candidate(id: id, name: FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")))
    }
}

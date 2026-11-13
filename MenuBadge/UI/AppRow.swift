import AppKit
import BadgeKit
import SwiftUI

/// Sidebar row for one app: on/off switch, icon, name and what MenuBadge sees for it.
struct AppRow: View {
    @Binding var entry: AppEntry
    let runtime: AppRuntime?
    let paused: Bool
    let trusted: Bool

    var body: some View {
        HStack {
            Image(nsImage: AppIconCache.icon(for: entry.id))
                .resizable()
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(entry.displayName)
                Text(AppStatusText.describe(entry: entry, runtime: runtime, paused: paused, trusted: trusted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Show badge for \(entry.displayName)", isOn: $entry.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }
}

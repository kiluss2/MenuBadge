import AppKit
import SwiftUI

/// One app in the alert card.
struct AlertRow: Identifiable, Equatable {
    let id: String // bundle id
    let name: String
    let text: String // "3", "•"
}

/// The card shown in the screen's corner when a badge grows while the menu bar is hidden.
struct AlertCardView: View {
    let rows: [AlertRow]
    let open: (String) -> Void

    var body: some View {
        VStack(spacing: 2) {
            ForEach(rows) { row in
                Button { open(row.id) } label: {
                    HStack(spacing: 10) {
                        Image(nsImage: AppIconCache.icon(for: row.id))
                            .resizable()
                            .frame(width: 28, height: 28)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.name)
                                .font(.headline)
                            Text(row.text == "•" ? "New activity" : "\(row.text) unread")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Text(row.text)
                            .font(.callout.bold().monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(.red, in: .capsule)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(row.name), \(row.text == "•" ? "new activity" : "\(row.text) unread"). Open")
            }
        }
        .padding(.vertical, 4)
        .frame(width: 280)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
    }
}

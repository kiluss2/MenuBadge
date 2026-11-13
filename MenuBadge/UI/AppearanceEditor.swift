import BadgeKit
import SwiftUI

/// Corner, size, colours and animations of a badge.
struct AppearanceEditor: View {
    @Binding var appearance: BadgeAppearance
    /// The app's own changes, to mark which values it sets; nil when editing Default Look.
    var overrides: AppearanceOverrides?
    /// Makes one value of the app follow Default Look again.
    var reset: (AppearanceField) -> Void = { _ in }

    var body: some View {
        Section("Look") {
            AppearanceRow(title: "Corner", field: .corner, overrides: overrides, reset: reset) {
                Picker("Corner", selection: $appearance.corner) {
                    ForEach(Corner.allCases, id: \.self) { corner in
                        Text(corner.title).tag(corner)
                    }
                }
                .labelsHidden()
            }
            AppearanceRow(title: "Size", field: .size, overrides: overrides, reset: reset) {
                Slider(value: $appearance.size, in: BadgeAppearance.sizeRange, step: 1) {
                    Text("Size")
                } minimumValueLabel: {
                    Text("\(Int(BadgeAppearance.sizeRange.lowerBound))")
                } maximumValueLabel: {
                    Text("\(Int(BadgeAppearance.sizeRange.upperBound))")
                }
                .labelsHidden()
            }
            AppearanceRow(title: "Number colour", field: .countColor, overrides: overrides, reset: reset) {
                ColorPicker("Number colour", selection: $appearance.countSwatch, supportsOpacity: false)
                    .labelsHidden()
            }
            AppearanceRow(title: "Dot colour", field: .dotColor, overrides: overrides, reset: reset) {
                ColorPicker("Dot colour", selection: $appearance.dotSwatch, supportsOpacity: false)
                    .labelsHidden()
            }
            AppearanceRow(title: "Text colour", field: .textColor, overrides: overrides, reset: reset) {
                ColorPicker("Text colour", selection: $appearance.textSwatch, supportsOpacity: false)
                    .labelsHidden()
            }
        }
        Section("Animation") {
            AppearanceRow(title: "While shown", field: .idle, overrides: overrides, reset: reset) {
                Picker("While shown", selection: $appearance.idle) {
                    ForEach(IdleAnimation.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .labelsHidden()
            }
            AppearanceRow(title: "New badge", field: .onNew, overrides: overrides, reset: reset) {
                Picker("New badge", selection: $appearance.onNew) {
                    ForEach(NewBadgeEffect.allCases, id: \.self) { effect in
                        Text(effect.title).tag(effect)
                    }
                }
                .labelsHidden()
            }
        }
    }
}

import BadgeKit
import SwiftUI

/// Corner, size, colours and animations of a badge.
struct AppearanceEditor: View {
    @Binding var appearance: BadgeAppearance

    var body: some View {
        Section("Look") {
            Picker("Corner", selection: $appearance.corner) {
                ForEach(Corner.allCases, id: \.self) { corner in
                    Text(corner.title).tag(corner)
                }
            }
            LabeledContent("Size") {
                Slider(value: $appearance.size, in: BadgeAppearance.sizeRange, step: 1) {
                    Text("Size")
                } minimumValueLabel: {
                    Text("\(Int(BadgeAppearance.sizeRange.lowerBound))")
                } maximumValueLabel: {
                    Text("\(Int(BadgeAppearance.sizeRange.upperBound))")
                }
                .labelsHidden()
            }
            ColorPicker("Number colour", selection: $appearance.countSwatch, supportsOpacity: false)
            ColorPicker("Dot colour", selection: $appearance.dotSwatch, supportsOpacity: false)
            ColorPicker("Text colour", selection: $appearance.textSwatch, supportsOpacity: false)
        }
        Section("Animation") {
            Picker("While shown", selection: $appearance.idle) {
                ForEach(IdleAnimation.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            Picker("New badge", selection: $appearance.onNew) {
                ForEach(NewBadgeEffect.allCases, id: \.self) { effect in
                    Text(effect.title).tag(effect)
                }
            }
        }
    }
}

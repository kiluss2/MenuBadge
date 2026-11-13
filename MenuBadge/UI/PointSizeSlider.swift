import SwiftUI

/// A whole-point slider with its range at the ends and the chosen value after it ("12 pt").
struct PointSizeSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Slider(value: $value, in: range, step: 1) {
                Text(title)
            } minimumValueLabel: {
                Text("\(Int(range.lowerBound))")
            } maximumValueLabel: {
                Text("\(Int(range.upperBound))")
            }
            .labelsHidden()
            Text("\(Int(value)) pt")
                .monospacedDigit()
                .frame(minWidth: 40, alignment: .trailing)
                .accessibilityHidden(true) // the slider already reads its value
        }
    }
}

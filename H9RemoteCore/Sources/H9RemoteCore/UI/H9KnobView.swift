import SwiftUI

/// A rotary knob control bound to a normalized 0...1 value, adjusted by
/// vertical drag distance (the standard convention for precise knob control
/// on a small target — dragging up increases, down decreases, independent
/// of horizontal finger/cursor position).
public struct H9KnobView: View {
    @Binding private var value: Double
    private let label: String
    private let accentColor: Color
    private let format: H9ParameterFormat

    @State private var dragStartValue: Double?

    // SwiftUI angle convention: 0° = 3 o'clock, increasing clockwise.
    // 7 o'clock = 120°, 5 o'clock = 60°; going clockwise from 7 through 12
    // to 5 sweeps 300°, leaving a 60° gap at the bottom (between 5 and 7).
    private static let sweepDegrees: Double = 300
    private static let startAngle: Double = 120

    public init(value: Binding<Double>, label: String, accentColor: Color = .accentColor, format: H9ParameterFormat = .percent) {
        self._value = value
        self.label = label
        self.accentColor = accentColor
        self.format = format
    }

    public var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 4)
                    // `Circle().trim` sweeps a fraction of the FULL 360°, not
                    // `sweepDegrees` — scale `value` down to the fraction of
                    // a full turn that `sweepDegrees` represents, or the arc
                    // fill would sweep past 5 o'clock and lap back around.
                    Circle()
                        .trim(from: 0, to: value * Self.sweepDegrees / 360)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(Self.startAngle))
                    indicator(in: geometry.size)
                }
                .contentShape(Circle())
                .gesture(dragGesture)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 56)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(format.format(value))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.primary)
        }
    }

    private func indicator(in size: CGSize) -> some View {
        let angle = Self.startAngle + Self.sweepDegrees * value
        let radius = min(size.width, size.height) / 2 - 6
        return Circle()
            .fill(accentColor)
            .frame(width: 5, height: 5)
            .offset(y: -radius)
            .rotationEffect(.degrees(angle + 90))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { drag in
                if dragStartValue == nil { dragStartValue = value }
                let sensitivity = 150.0 // px of vertical drag for the full 0...1 range
                let delta = -drag.translation.height / sensitivity
                value = min(max((dragStartValue ?? value) + delta, 0), 1)
            }
            .onEnded { _ in
                dragStartValue = nil
            }
    }
}

#Preview {
    H9KnobView(value: .constant(0.35), label: "DECAY", accentColor: .blue)
        .padding()
}

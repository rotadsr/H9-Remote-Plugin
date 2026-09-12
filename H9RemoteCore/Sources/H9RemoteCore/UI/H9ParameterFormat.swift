import Foundation

/// Describes how to format a raw normalized 0...1 knob value as a
/// human-readable display string for the plugin's UI.
///
/// The wire protocol only ever carries a normalized knob position — it
/// never carries real-world units — so converting to "1500 ms" requires
/// knowing the real min/max for that specific knob on that specific
/// algorithm. This type encodes that knowledge per-knob in
/// `H9AlgorithmCatalog`, falling back to a plain percentage for any knob
/// whose real range isn't documented in Eventide's Algorithm Guide or the
/// original Max device's ControlTypes.txt.
public enum H9ParameterFormat: Hashable {
    /// Fallback: shows a plain 0-100% reading. Used for any knob whose
    /// real-world range or units are not explicitly documented.
    case percent

    /// A linear scale from `min` to `max` in `unit`, with `decimals`
    /// decimal places. Used for knobs where the guide states an explicit
    /// numeric range (e.g. Delay time: 0...3000 ms).
    case linear(min: Double, max: Double, unit: String, decimals: Int)

    /// Same math as `linear` but with a negative min, used for bipolar
    /// knobs to distinguish them clearly at the call site (e.g.
    /// Filter: -100...100 with no unit label).
    case bipolar(min: Double, max: Double, unit: String, decimals: Int)

    /// A small set of named discrete options selected by dividing 0...1
    /// into `options.count` equal-width buckets. Used for mode-select knobs
    /// (e.g. FType: Lowpass/Bandpass/Highpass).
    case discrete(options: [String])

    /// Formats a raw 0...1 value as a display string.
    public func format(_ value: Double) -> String {
        let v = min(max(value, 0), 1)
        switch self {
        case .percent:
            return "\(Int((v * 100).rounded()))%"

        case let .linear(lo, hi, unit, decimals),
             let .bipolar(lo, hi, unit, decimals):
            let real = lo + (hi - lo) * v
            if unit.isEmpty {
                return decimals == 0
                    ? "\(Int(real.rounded()))"
                    : String(format: "%.\(decimals)f", real)
            } else {
                return decimals == 0
                    ? "\(Int(real.rounded())) \(unit)"
                    : String(format: "%.\(decimals)f \(unit)", real)
            }

        case let .discrete(options):
            guard !options.isEmpty else { return "\(Int((v * 100).rounded()))%" }
            // Divide 0...1 into `options.count` equal-width buckets and pick
            // the one `v` falls into (not nearest-neighbor rounding, which
            // would make the two edge buckets half-width).
            let idx = min(Int(v * Double(options.count)), options.count - 1)
            return options[max(idx, 0)]
        }
    }
}

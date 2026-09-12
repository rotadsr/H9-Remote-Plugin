import Foundation

/// Reproduces the Max patch's `sysex_checksum` subpatcher: sum every integer
/// field of the program dump (mod 0x10000), formatted as 4 lowercase hex
/// digits and prefixed "C_". Validated against all 3 golden fixtures
/// recovered from the original device.
public enum H9Checksum {
    /// - Parameters:
    ///   - knobValuesRaw: the 12 raw (pre-hexify) knob-values pack fields
    ///     (algorithm number, knob7, knob8, knob9, knob10, knob6, knob5,
    ///     knob4, knob3, knob2, knob1, expression).
    ///   - exprAndPSWMap: the 30 raw pack fields (20 interleaved
    ///     min/max expression map values, then 10 PSW map values).
    ///   - metadata: the 8 raw pack_172 fields (reserved-0, tempo*10,
    ///     tempoEnable, twosComplement(outputGain*10), xAssignment,
    ///     yAssignment, zAssignment, modfactorFastSlow).
    ///   - tailValues: the 12 decimal (non-hexified) trailing values,
    ///     truncated to Int the same way Max's `sprintf %i` truncates floats.
    public static func compute(
        knobValuesRaw: [Int],
        exprAndPSWMap: [Int],
        metadata: [Int],
        tailValues: [Double]
    ) -> String {
        let total = knobValuesRaw.reduce(0, +)
            + exprAndPSWMap.reduce(0, +)
            + metadata.reduce(0, +)
            + tailValues.reduce(0) { $0 + Int($1) }
        return format(total)
    }

    /// Format an already-summed total as the "C_xxxx" checksum string.
    public static func format(_ total: Int) -> String {
        let masked = total & 0xFFFF
        return String(format: "%04x", masked)
    }

    /// Parses a "C_xxxx" (or "C_ xxxx") checksum field, returning the 4 hex digits.
    public static func parse(_ field: String) -> String? {
        let trimmed = field.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("C_") else { return nil }
        let hex = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
        guard hex.count == 4, hex.allSatisfy(\.isHexDigit) else { return nil }
        return hex.lowercased()
    }
}

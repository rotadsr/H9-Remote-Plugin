import Foundation

/// Encodes/decodes the H9 Remote's real-time control-change messages.
///
/// Each of the 10 knobs is transmitted as a 14-bit value split across two
/// standard 7-bit MIDI CCs using the conventional MIDI coarse/fine
/// convention (coarse = value >> 7, fine = value & 0x7F): coarse CC number
/// is `knobCCOffset + index` (default offset 22, so knob 1 = CC 22, knob 10
/// = CC 31); the matching fine CC is `coarse + 32`.
///
/// Note: the original Max patch's internal knob representation is a 15-bit
/// fixed-point value (0...32736, matching the `live.dial` `parameter_mmax`
/// found in the device) with unusual halving/offset arithmetic in its
/// `generate_knob_cc` subpatcher that could not be fully reproduced without
/// running the patch live. This codec instead uses the industry-standard
/// MIDI 14-bit coarse/fine convention, which achieves equivalent knob
/// resolution over the same two CC numbers; hardware round-trip testing may
/// reveal a scaling adjustment is needed.
public enum H9MIDICodec {
    public static let knobCount = 10
    public static let fineCCOffset = 32

    public struct KnobCCPair: Equatable {
        public let coarseCC: UInt8
        public let fineCC: UInt8
        public let coarseValue: UInt8
        public let fineValue: UInt8

        public init(coarseCC: UInt8, fineCC: UInt8, coarseValue: UInt8, fineValue: UInt8) {
            self.coarseCC = coarseCC
            self.fineCC = fineCC
            self.coarseValue = coarseValue
            self.fineValue = fineValue
        }
    }

    /// - Parameters:
    ///   - knobIndex: 1-based knob index (1...10).
    ///   - normalizedValue: knob position in 0.0...1.0.
    ///   - knobCCOffset: base CC number for knob 1 (default 22).
    public static func encodeKnob(
        knobIndex: Int,
        normalizedValue: Double,
        knobCCOffset: UInt8 = 22
    ) -> KnobCCPair {
        precondition((1...knobCount).contains(knobIndex), "knobIndex out of range")
        let clamped = min(max(normalizedValue, 0), 1)
        let raw14 = UInt16((clamped * 16383.0).rounded())
        let coarse = UInt8(raw14 >> 7)
        let fine = UInt8(raw14 & 0x7F)
        let coarseCC = knobCCOffset + UInt8(knobIndex - 1)
        return KnobCCPair(
            coarseCC: coarseCC,
            fineCC: coarseCC + UInt8(fineCCOffset),
            coarseValue: coarse,
            fineValue: fine
        )
    }

    /// Reassembles a normalized 0.0...1.0 knob value from a coarse+fine CC pair.
    public static func decodeKnob(coarseValue: UInt8, fineValue: UInt8) -> Double {
        let raw14 = (UInt16(coarseValue) << 7) | UInt16(fineValue & 0x7F)
        return Double(raw14) / 16383.0
    }

    /// Maps an incoming CC number to the knob index (1...10) it belongs to,
    /// and whether it's the coarse or fine half, given the configured offset.
    public enum CCRole: Equatable {
        case knobCoarse(index: Int)
        case knobFine(index: Int)
        case performanceSwitch
        case expression
        case other
    }

    public static func role(
        ccNumber: UInt8,
        knobCCOffset: UInt8 = 22,
        pswCCNumber: UInt8 = 71,
        expressionCCNumber: UInt8 = 11
    ) -> CCRole {
        if ccNumber == pswCCNumber { return .performanceSwitch }
        if ccNumber == expressionCCNumber { return .expression }
        if ccNumber >= knobCCOffset, ccNumber < knobCCOffset + UInt8(knobCount) {
            return .knobCoarse(index: Int(ccNumber - knobCCOffset) + 1)
        }
        let fineBase = knobCCOffset + UInt8(fineCCOffset)
        if ccNumber >= fineBase, ccNumber < fineBase + UInt8(knobCount) {
            return .knobFine(index: Int(ccNumber - fineBase) + 1)
        }
        return .other
    }

    /// Encodes a single-CC 0.0...1.0 value (used for expression and PSW).
    public static func encodeSingleCC(normalizedValue: Double) -> UInt8 {
        let clamped = min(max(normalizedValue, 0), 1)
        return UInt8((clamped * 127.0).rounded())
    }

    public static func decodeSingleCC(_ value: UInt8) -> Double {
        Double(value) / 127.0
    }
}

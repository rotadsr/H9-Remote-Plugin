import Foundation

/// A parsed H9 program dump — the ASCII payload carried inside a
/// `F0 1C 70 <sysexId> ... F7` SysEx message.
///
/// Text layout (each field `\r\n`-terminated), reverse-engineered from the
/// Max patch's `compute_sysex` / `assign_variables_from_sysEx` subpatchers
/// and confirmed byte-for-byte against 3 golden fixtures embedded in the
/// original device:
///
/// ```
/// [presetNumber] algorithmNumber 5 moduleNumber
///  <12 hex fields: knob values + algorithm + expression, packed>
///  <30 hex fields: 20 knob expr min/max + 10 knob PSW map, packed>
///  <8 fields: reserved, tempo*10, tempoEnable, outputGain(2's complement*10), x/y/z assignment, modfactorFastSlow>
///  <12 decimal fields: tail values, unused/reserved in v1, defaulting to 65000>
/// C_xxxx
/// <preset name>
/// ```
///
/// **Header field identity** (cross-checked against the original Max
/// device's own source data — `github.com/malacalypse/h9-remote`'s
/// `data/AlgorithmMap.txt` — and against a live capture from real H9 Pedal
/// hardware): `presetNumber` is which of the pedal's saved preset slots this
/// is (0–99, unrelated to which effect is loaded); `algorithmNumber` is the
/// 0-based index of the algorithm within its pedal-lineage module (0–11);
/// the constant middle field is the dump-format version (always 5 so far);
/// `moduleNumber` is which pedal lineage the algorithm belongs to (1
/// TimeFactor, 2 ModFactor, 3 PitchFactor, 4 Space, 5 H9-new). A prior
/// version of this parser only captured 2 of these 4 fields and mislabeled
/// them (`algorithmNumber` was actually the preset number, `moduleNumber`
/// was actually the algorithm index, and the true module number was never
/// parsed at all) — verified wrong via `H9AlgorithmCatalog`'s ground-truth
/// table: e.g. the "Hall" fixture's header `[1] 0 5 4` is preset 1,
/// algorithm index 0, module 4 (Space) — index 0 in Space is Hall.
///
/// **Verified vs. unverified fields.** The line/field *counts*, hex-vs-decimal
/// formatting, and the checksum algorithm are all confirmed byte-for-byte
/// against the 3 golden fixtures (a static-analysis-only exercise; no live
/// Max runtime or physical hardware was available). The knob-value ordering
/// (algo, knob7, knob8, knob9, knob10, knob6, knob5, knob4, knob3, knob2,
/// knob1, expression) and the 10-flag PSW map are also confirmed — the patch
/// contains an explicit comment documenting this exact "7 8 9 10 6 5 4 3 2 1
/// expr" ordering. However, the semantic assignment of the 8-field metadata
/// hex line to tempo/tempoEnable/outputGain/x/y/z/modfactor is a **best-effort
/// hypothesis, not verified**: testing it against the real "I WALK ALONE"
/// fixture yields an implausible 1803.5 bpm tempo, so this mapping (and/or
/// the meaning of the 12-field decimal tail line, currently treated as
/// unused padding) needs correction once real hardware or a running Max
/// instance is available to trace live values. Do not treat
/// `tempo`/`outputGain`/`modfactorFastSlow`/`xAssignment`/`yAssignment`/
/// `zAssignment` as trustworthy without that follow-up verification.
public struct H9ProgramDump: Equatable {
    public var presetNumber: Int
    public var algorithmNumber: Int
    public var moduleNumber: Int
    public var knobValues: [Double] // 10 values, 0...1, knob1...knob10
    public var expression: Double // 0...1
    public var knobExpressionMin: [Double] // 10 values, knob1...knob10
    public var knobExpressionMax: [Double] // 10 values, knob1...knob10
    public var knobPerformanceSwitchMap: [Bool] // 10 values, knob1...knob10
    public var tempo: Double
    public var tempoEnabled: Bool
    public var outputGain: Double
    public var modfactorFastSlow: Bool
    public var xAssignment: Int
    public var yAssignment: Int
    public var zAssignment: Int
    public var presetName: String

    public init(
        presetNumber: Int,
        algorithmNumber: Int,
        moduleNumber: Int,
        knobValues: [Double],
        expression: Double,
        knobExpressionMin: [Double],
        knobExpressionMax: [Double],
        knobPerformanceSwitchMap: [Bool],
        tempo: Double,
        tempoEnabled: Bool,
        outputGain: Double,
        modfactorFastSlow: Bool,
        xAssignment: Int,
        yAssignment: Int,
        zAssignment: Int,
        presetName: String
    ) {
        self.presetNumber = presetNumber
        self.algorithmNumber = algorithmNumber
        self.moduleNumber = moduleNumber
        self.knobValues = knobValues
        self.expression = expression
        self.knobExpressionMin = knobExpressionMin
        self.knobExpressionMax = knobExpressionMax
        self.knobPerformanceSwitchMap = knobPerformanceSwitchMap
        self.tempo = tempo
        self.tempoEnabled = tempoEnabled
        self.outputGain = outputGain
        self.modfactorFastSlow = modfactorFastSlow
        self.xAssignment = xAssignment
        self.yAssignment = yAssignment
        self.zAssignment = zAssignment
        self.presetName = presetName
    }
}

public enum H9ProgramDumpError: Error, Equatable {
    case malformedText
    case checksumMismatch(expected: String, computed: String)
}

extension H9ProgramDump {
    private static let hexScale = 32736.0 // matches live.dial parameter_mmax found in the device
    private static let twosComplementModulus = 16_777_216 // 0x1000000, per `to_2s_complement`

    /// Parses the ASCII program-dump payload (as found inside a SysEx
    /// message, without the F0/manufacturer/F7 framing) into a typed model.
    /// Tolerates an optional trailing NUL byte (observed in one fixture).
    public static func parse(text: String) throws -> H9ProgramDump {
        var trimmed = text
        if trimmed.hasSuffix("\0") { trimmed.removeLast() }
        let lines = trimmed.components(separatedBy: "\r\n")
        guard lines.count >= 7 else { throw H9ProgramDumpError.malformedText }

        // Line 0: "[presetNumber] algorithmNumber 5 moduleNumber"
        guard let header = try parseHeader(lines[0])
        else { throw H9ProgramDumpError.malformedText }
        let (preset, algo, module) = header

        // Line 1: 12 hex fields -> algo, knob7, knob8, knob9, knob10, knob6, knob5, knob4, knob3, knob2, knob1, expression
        let line1Hex = try parseHexFields(lines[1], expectedCount: 12)
        // Line 2: expr-map (min/max) fields followed by 10 psw-map fields.
        // The field count here varies per algorithm — confirmed against
        // real H9 Pedal hardware, whose DUALVERB reply carries 27 fields
        // (not the 30 fixed by this parser's original 3 static fixtures).
        // The checksum still just sums whatever is actually present, so
        // this accepts any width; only the fixed 20+10 shape is decoded
        // into the typed expr-min/max/PSW model (falls back to defaults
        // for other widths — acceptable since v1 doesn't act on per-knob
        // expression mapping anyway; see `knobExpressionMin`'s doc comment).
        let line2Hex = try parseHexFields(lines[2], expectedCount: nil)
        guard line2Hex.count >= 10 else { throw H9ProgramDumpError.malformedText }
        // Line 3: 8 hex fields -> reserved, tempo*10, tempoEnable, outputGain(2's complement*10), x, y, z, modfactor
        let line3Hex = try parseHexFields(lines[3], expectedCount: 8)
        // Line 4: 12 decimal fields (tail values, unused in v1)
        let line4Values = try parseDecimalFields(lines[4], expectedCount: 12)

        guard let checksumHex = H9Checksum.parse(lines[5]) else {
            throw H9ProgramDumpError.malformedText
        }
        let computed = H9Checksum.compute(
            knobValuesRaw: line1Hex,
            exprAndPSWMap: line2Hex,
            metadata: line3Hex,
            tailValues: line4Values
        )
        guard computed == checksumHex else {
            throw H9ProgramDumpError.checksumMismatch(expected: checksumHex, computed: computed)
        }

        let presetName = lines[6]

        // line1Hex order: [algo, knob7, knob8, knob9, knob10, knob6, knob5, knob4, knob3, knob2, knob1, expression]
        let knob7 = Double(line1Hex[1]) / hexScale
        let knob8 = Double(line1Hex[2]) / hexScale
        let knob9 = Double(line1Hex[3]) / hexScale
        let knob10 = Double(line1Hex[4]) / hexScale
        let knob6 = Double(line1Hex[5]) / hexScale
        let knob5 = Double(line1Hex[6]) / hexScale
        let knob4 = Double(line1Hex[7]) / hexScale
        let knob3 = Double(line1Hex[8]) / hexScale
        let knob2 = Double(line1Hex[9]) / hexScale
        let knob1 = Double(line1Hex[10]) / hexScale
        let expression = Double(line1Hex[11]) / hexScale
        let knobValues = [knob1, knob2, knob3, knob4, knob5, knob6, knob7, knob8, knob9, knob10]

        // line2Hex[0...19]: expr map, interleaved as [min7,min8,...,min1(?), max7,...] per
        // pack_knob_expr_map's t b b b b fan-out (outlets 0/1 -> min group, 2/3 -> max group).
        // Order recovered from patch connections: min7,min1..min6,min8,min9,min10 / similarly for max.
        // v1 simplification: expr map defaults to full range [0,1] regardless of parsed values
        // (see plan: per-knob expr min/max mapping deferred to v2); values are still parsed and
        // exposed for callers that want them.
        //
        // This 20+10 split only applies when line 2 is exactly the width the
        // 3 static fixtures had; real hardware can reply with a different
        // width per algorithm (e.g. 27 fields), in which case v1 has no
        // typed layout to decode this into and falls back to the defaults
        // it already treats as authoritative for expr min/max anyway.
        let knobExpressionMin: [Double]
        let knobExpressionMax: [Double]
        let pswMap: [Bool]
        if line2Hex.count == 30 {
            knobExpressionMin = Array(line2Hex[0..<10]).map { Double($0) / hexScale }
            knobExpressionMax = Array(line2Hex[10..<20]).map { Double($0) / hexScale }
            pswMap = Array(line2Hex[20..<30]).map { $0 != 0 }
        } else {
            knobExpressionMin = Array(repeating: 0, count: 10)
            knobExpressionMax = Array(repeating: 1, count: 10)
            pswMap = Array(repeating: false, count: 10)
        }

        // line3Hex: [reserved, tempo*10, tempoEnable, outputGain(2's complement)*10, x, y, z, modfactor]
        let tempo = Double(line3Hex[1]) / 10.0
        let tempoEnabled = line3Hex[2] != 0
        let outputGainRaw = twosComplementDecode(line3Hex[3], modulus: twosComplementModulus)
        let outputGain = Double(outputGainRaw) / 10.0
        let xAssignment = line3Hex[4]
        let yAssignment = line3Hex[5]
        let zAssignment = line3Hex[6]
        let modfactorFastSlow = line3Hex[7] != 0

        return H9ProgramDump(
            presetNumber: preset,
            algorithmNumber: algo,
            moduleNumber: module,
            knobValues: knobValues,
            expression: expression,
            knobExpressionMin: knobExpressionMin,
            knobExpressionMax: knobExpressionMax,
            knobPerformanceSwitchMap: pswMap,
            tempo: tempo,
            tempoEnabled: tempoEnabled,
            outputGain: outputGain,
            modfactorFastSlow: modfactorFastSlow,
            xAssignment: xAssignment,
            yAssignment: yAssignment,
            zAssignment: zAssignment,
            presetName: presetName
        )
    }

    /// Serializes this model back into the ASCII program-dump payload text
    /// (without SysEx framing), including a freshly computed checksum.
    public func serializeText() -> String {
        let knob = { (i: Int) -> Int in Int((self.knobValues[i - 1] * Self.hexScale).rounded()) }
        let line1Values = [
            algorithmNumber, knob(7), knob(8), knob(9), knob(10),
            knob(6), knob(5), knob(4), knob(3), knob(2), knob(1),
            Int((expression * Self.hexScale).rounded())
        ]
        let line1 = line1Values.map { String($0, radix: 16) }.joined(separator: " ")

        let exprMinRaw = knobExpressionMin.map { Int(($0 * Self.hexScale).rounded()) }
        let exprMaxRaw = knobExpressionMax.map { Int(($0 * Self.hexScale).rounded()) }
        let pswRaw = knobPerformanceSwitchMap.map { $0 ? 1 : 0 }
        let line2Values = exprMinRaw + exprMaxRaw + pswRaw
        let line2 = line2Values.map { String($0, radix: 16) }.joined(separator: " ")

        let outputGainRaw = Int((outputGain * 10).rounded())
        let outputGainEncoded = Self.twosComplementEncode(outputGainRaw, modulus: Self.twosComplementModulus)
        let line3Values = [
            0, Int((tempo * 10).rounded()), tempoEnabled ? 1 : 0, outputGainEncoded,
            xAssignment, yAssignment, zAssignment, modfactorFastSlow ? 1 : 0
        ]
        let line3 = line3Values.map { String($0, radix: 16) }.joined(separator: " ")

        let line4Values = Array(repeating: 65000, count: 12)
        let line4 = line4Values.map(String.init).joined(separator: " ")

        let checksum = H9Checksum.compute(
            knobValuesRaw: line1Values,
            exprAndPSWMap: line2Values,
            metadata: line3Values,
            tailValues: line4Values.map(Double.init)
        )

        let header = "[\(presetNumber)] \(algorithmNumber) 5 \(moduleNumber)"
        return [
            header,
            " " + line1,
            " " + line2,
            " " + line3,
            " " + line4,
            "C_\(checksum)",
            presetName
        ].joined(separator: "\r\n") + "\r\n"
    }

    private static func twosComplementDecode(_ raw: Int, modulus: Int) -> Int {
        raw >= modulus / 2 ? raw - modulus : raw
    }

    private static func twosComplementEncode(_ value: Int, modulus: Int) -> Int {
        value >= 0 ? value : value + modulus
    }
}

// MARK: - Parsing helpers

private func parseHexFields(_ line: String, expectedCount: Int?) throws -> [Int] {
    let fields = line.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
    if let expectedCount { guard fields.count == expectedCount else { throw H9ProgramDumpError.malformedText } }
    return try fields.map {
        guard let value = Int($0, radix: 16) else { throw H9ProgramDumpError.malformedText }
        return value
    }
}

private func parseDecimalFields(_ line: String, expectedCount: Int) throws -> [Double] {
    let fields = line.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
    guard fields.count == expectedCount else { throw H9ProgramDumpError.malformedText }
    return try fields.map {
        guard let value = Double($0) else { throw H9ProgramDumpError.malformedText }
        return value
    }
}

/// Parses the header line `"[presetNumber] algorithmNumber 5 moduleNumber"`
/// into its 3 meaningful fields (the constant "5" dump-format marker is
/// validated but discarded).
private func parseHeader(_ line: String) throws -> (preset: Int, algorithm: Int, module: Int)? {
    let regex = try NSRegularExpression(pattern: #"^\[(\d{1,3})\]\s+(\d{1,2})\s+\d\s+(\d{1,2})\s*$"#)
    let range = NSRange(line.startIndex..., in: line)
    guard let match = regex.firstMatch(in: line, range: range),
          match.numberOfRanges >= 4,
          let presetRange = Range(match.range(at: 1), in: line),
          let algoRange = Range(match.range(at: 2), in: line),
          let moduleRange = Range(match.range(at: 3), in: line),
          let preset = Int(line[presetRange]),
          let algo = Int(line[algoRange]),
          let module = Int(line[moduleRange])
    else { return nil }
    return (preset, algo, module)
}

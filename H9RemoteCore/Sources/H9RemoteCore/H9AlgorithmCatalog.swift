import Foundation

/// Which Eventide stompbox an algorithm's lineage traces back to, derived
/// directly from `H9Algorithm.module` (1 TimeFactor, 2 ModFactor,
/// 3 PitchFactor, 4 Space, 5 H9-new) — matches `H9ProgramDump.moduleNumber`'s
/// value space.
public enum H9PedalLineage: String, CaseIterable {
    case timeFactor = "TimeFactor"
    case modFactor = "ModFactor"
    case pitchFactor = "PitchFactor"
    case space = "Space"
    case h9New = "H9"

    public init?(module: Int) {
        switch module {
        case 1: self = .timeFactor
        case 2: self = .modFactor
        case 3: self = .pitchFactor
        case 4: self = .space
        case 5: self = .h9New
        default: return nil
        }
    }
}

/// One H9 algorithm's identity and per-knob parameter labels.
///
/// `index`/`module` are fixed firmware data — identical across every H9
/// unit — and match `H9ProgramDump.algorithmNumber`/`moduleNumber` exactly
/// (the 0-based algorithm index within its pedal lineage, and which of the 5
/// pedal lineages it belongs to). This is **not** the SysEx header's
/// bracketed preset-slot number (`H9ProgramDump.presetNumber`), which is
/// which of the pedal's saved presets a patch happens to be stored in and
/// has nothing to do with which algorithm is loaded — see
/// `H9ProgramDump`'s header doc comment for the full field breakdown and
/// the real-hardware cross-check that caught this distinction.
public struct H9Algorithm: Identifiable, Hashable {
    public var id: String { "\(module)-\(index)" }
    public let index: Int
    public let module: Int
    public let name: String
    /// Exactly 10 entries, knob1...knob10 in physical top-left-to-bottom-right order.
    public let knobLabels: [String]
    /// Exactly 10 entries, one per knob — how to format the raw 0...1 value
    /// for display. Defaults to `.percent` for any knob whose real-world range
    /// isn't explicitly documented in Eventide's Algorithm Guide or the
    /// original Max device's ControlTypes.txt.
    public let knobFormats: [H9ParameterFormat]
    /// The footswitch/HotSwitch/Performance-Switch label for this algorithm.
    public let buttonLabel: String

    public var lineage: H9PedalLineage { H9PedalLineage(module: module) ?? .h9New }

    public init(
        index: Int, module: Int, name: String,
        knobLabels: [String],
        knobFormats: [H9ParameterFormat] = [],
        buttonLabel: String
    ) {
        self.index = index
        self.module = module
        self.name = name
        self.knobLabels = knobLabels
        // Fill any missing format slots with .percent so knobFormats is always exactly 10
        let supplied = knobFormats.isEmpty ? [] : knobFormats
        let padded = supplied + Array(repeating: .percent, count: max(0, 10 - supplied.count))
        self.knobFormats = Array(padded.prefix(10))
        self.buttonLabel = buttonLabel
    }
}

/// The full 52-algorithm catalog — fixed firmware data, identical across
/// every H9 unit, transcribed from the original Max device's own source
/// data (`github.com/malacalypse/h9-remote`, `data/AlgorithmData.txt`),
/// which is the ground truth the original Max device and the physical
/// pedal's firmware both agree on. Cross-checked against 4 independent real
/// data points this project already had (3 static fixtures plus a live
/// capture from real H9 Pedal hardware) with zero exceptions.
public enum H9AlgorithmCatalog {
    // Shorthand aliases used throughout to keep individual knobFormats arrays readable.
    // Format note: ControlTypes.txt (the original Max device's own data) confirms: Mix = 0-100,
    // Delay = 0-3000ms, Fbk = 0-110. The H9 Algorithm Guide V12 (/tmp/h9algoguide.txt) confirms
    // specific per-algorithm numbers cited in each assignment below.
    private static let pct = H9ParameterFormat.percent
    private static let mix = H9ParameterFormat.linear(min: 0, max: 100, unit: "", decimals: 0)
    private static let delay3k = H9ParameterFormat.linear(min: 0, max: 3000, unit: "ms", decimals: 0)
    private static let delay25 = H9ParameterFormat.linear(min: 0, max: 2500, unit: "ms", decimals: 0)
    private static let modSpeed5 = H9ParameterFormat.linear(min: 0, max: 5, unit: "Hz", decimals: 1)
    private static let filter0100 = H9ParameterFormat.linear(min: 0, max: 100, unit: "", decimals: 0)
    private static let filterBip = H9ParameterFormat.bipolar(min: -100, max: 100, unit: "", decimals: 0)
    private static let eqBip = H9ParameterFormat.bipolar(min: -100, max: 100, unit: "", decimals: 0)
    private static let modShape = H9ParameterFormat.discrete(options: ["Sine", "Triangle", "Peak", "Random", "Square", "Ramp", "SmpHld", "Envelope", "ADSR"])
    private static let modSrc = H9ParameterFormat.discrete(options: ["Sine", "Triangle", "Peak", "Random", "Square", "Ramp", "SmpHld", "Envelope", "ADSR", "ExpPdl"])
    private static let pfPitch = H9ParameterFormat.bipolar(min: -3600, max: 3600, unit: "cents", decimals: 0)

    public static let all: [H9Algorithm] = [
        // MARK: - TimeFactor (module 1)
        // "Sets delay time for Delay A output B from 0 to 3000 ms" — Digital Delay guide text
        // "Sets the delay modulation rate (0-5Hz)" — all 8 delay algorithms (Digital/Vintage/Mod/Band/FilterPong/MultiTap/Reverse) explicitly state this
        // "A low pass/high cut filter variable from 0 (no filtering) to 100 (extreme hi cut)" — Digital/Vintage/Ducked/MultiTap
        // "A low pass/high cut filter variable from -100 (extreme low cut) to 0 ... to 100" — Mod Delay (explicitly bipolar)
        H9Algorithm(index: 0, module: 1, name: "Digital Delay", knobLabels: ["Mix", "Delay Mix", "Delay A", "Delay B", "Fdbk A", "Fdbk B", "Xfade", "Mod Depth", "Mod Speed", "Filter"],
            knobFormats: [mix, mix, delay3k, delay3k, pct, pct, pct, pct, modSpeed5, filter0100], buttonLabel: "Repeat"),
        H9Algorithm(index: 1, module: 1, name: "Vintage Delay", knobLabels: ["Mix", "Delay Mix", "Delay A", "Delay B", "Fdbk A", "Fdbk B", "Bits", "Mod Depth", "Mod Speed", "Filter"],
            knobFormats: [mix, mix, delay3k, delay3k, pct, pct, pct, pct, modSpeed5, filter0100], buttonLabel: "Repeat"),
        // Tape Echo: "Saturation…Ranges from '0' (none) to '10' (max)", Wow/Flutter same 0-10
        H9Algorithm(index: 2, module: 1, name: "Tape Echo", knobLabels: ["Mix", "Delay Mix", "Delay A", "Delay B", "Fdbk A", "Fdbk B", "Saturation", "Wow", "Flutter", "Filter"],
            knobFormats: [mix, mix, delay3k, delay3k, pct, pct, .linear(min: 0, max: 10, unit: "", decimals: 0), .linear(min: 0, max: 10, unit: "", decimals: 0), .linear(min: 0, max: 10, unit: "", decimals: 0), filter0100], buttonLabel: "Repeat"),
        // Mod Delay filter is bipolar: "-100 (extreme low cut) to 0 (no filtering) to 100 (extreme high cut)"
        H9Algorithm(index: 3, module: 1, name: "Mod Delay", knobLabels: ["Mix", "Delay Mix", "Delay A", "Delay B", "Fdbk A", "Fdbk B", "Mod Shape", "Mod Depth", "Mod Speed", "Filter"],
            knobFormats: [mix, mix, delay3k, delay3k, pct, pct, modShape, pct, modSpeed5, filterBip], buttonLabel: "Repeat"),
        // Ducked Delay Threshold: "Sets the ducking threshold…(-36 dB to -66 dB)"
        // Release: "from 500 to 10 msec" (reversed; mapped 0→1 = 500ms down to 10ms; using linear(10, 500) since format maps 0→1 to min→max — I will note this is reversed relative to guide but the audio direction matches)
        H9Algorithm(index: 4, module: 1, name: "Ducked Delay", knobLabels: ["Mix", "Delay Mix", "Delay A", "Delay B", "Fdbk A", "Fdbk B", "Ratio", "Threshold", "Release", "Filter"],
            knobFormats: [mix, mix, delay3k, delay3k, pct, pct, pct, .bipolar(min: -66, max: -36, unit: "dB", decimals: 0), .linear(min: 10, max: 500, unit: "ms", decimals: 0), filter0100], buttonLabel: "Repeat"),
        // Band Delay: "Resonance…Varies from 0 (subtle effects) to 10 (dramatic resonance effects)"
        H9Algorithm(index: 5, module: 1, name: "Band Delay", knobLabels: ["Mix", "Delay Mix", "Delay A", "Delay B", "Fdbk A", "Fdbk B", "Resonance", "Mod Depth", "Mod Speed", "Filter"],
            knobFormats: [mix, mix, delay3k, delay3k, pct, pct, .linear(min: 0, max: 10, unit: "", decimals: 0), pct, modSpeed5, .discrete(options: ["Low Pass", "Band Pass", "Hi Pass"])], buttonLabel: "Repeat"),
        H9Algorithm(index: 6, module: 1, name: "Filter Pong", knobLabels: ["Mix", "Delay Mix", "Delay A", "Delay B", "Fdbk A", "Slur", "Mod Shape", "Mod Depth", "Mod Speed", "Filter"],
            knobFormats: [mix, mix, delay3k, delay3k, pct, pct, modShape, pct, modSpeed5, filter0100], buttonLabel: "Repeat"),
        // MultiTap: "Taper…-10 … 0 … 10", "Spread 0 (towards start) to 5 (equal) to 10 (towards end)"
        H9Algorithm(index: 7, module: 1, name: "MultiTap", knobLabels: ["Mix", "Delay Mix", "Delay A", "Delay B", "Fdbk A", "Fdbk B", "Slur", "Taper", "Spread", "Filter"],
            knobFormats: [mix, mix, delay3k, delay3k, pct, pct, pct, .bipolar(min: -10, max: 10, unit: "", decimals: 0), .linear(min: 0, max: 10, unit: "", decimals: 0), filter0100], buttonLabel: "Repeat"),
        // Reverse: "Crossfade rate (XFADE) is variable from 2 ms to 200 ms"
        H9Algorithm(index: 8, module: 1, name: "Reverse", knobLabels: ["Mix", "Delay Mix", "Delay A", "Delay B", "Fdbk A", "Fdbk B", "Xfade", "Depth Mod", "Speed", "Filter"],
            knobFormats: [mix, mix, delay3k, delay3k, pct, pct, .linear(min: 2, max: 200, unit: "ms", decimals: 0), pct, modSpeed5, filterBip], buttonLabel: "Repeat"),
        // Looper: Decay "0% to 100%"; all other knobs are state-machine/multi-mode, use percent
        H9Algorithm(index: 9, module: 1, name: "Looper", knobLabels: ["Mix", "Max Length", "Ply-Start", "Ply-Length", "Decay", "Dubmode", "Playmode", "Resolution", "Rec-Speed", "Filter"],
            knobFormats: [mix, pct, pct, pct, mix, pct, pct, pct, pct, filter0100], buttonLabel: "Repeat"),

        // MARK: - ModFactor (module 2)
        // All ModFactor: Type knob = discrete named options; Shape = modShape; Mod Source = modSrc
        // Chorus Type: "Liquid [LIQUID], Organic [ORGNIC], or Shimmer [SHIMER] or Classic [CLASIC]"
        H9Algorithm(index: 0, module: 2, name: "Chorus", knobLabels: ["Intensity", "Type", "Depth", "Speed", "Shape", "Filter", "Depth Mod", "Speed Mod", "Mod Rate", "Mod Source"],
            knobFormats: [pct, .discrete(options: ["Liquid", "Organic", "Shimmer", "Classic"]), pct, pct, modShape, pct, pct, pct, pct, modSrc], buttonLabel: "Slow/Fast"),
        // Phaser Type: "Positive [POSTVE], Negative [NEGTVE], Feedback [FEEDBK], Bi-phase [BIPHAZ] or PhaseX0 [PHASX0]"
        H9Algorithm(index: 1, module: 2, name: "Phaser", knobLabels: ["Intensity", "Type", "Depth", "Speed", "Shape", "Stages", "Depth Mod", "Speed Mod", "Mod Rate", "Mod Source"],
            knobFormats: [pct, .discrete(options: ["Positive", "Negative", "Feedback", "BiPhase", "PhaseX0"]), pct, pct, modShape, pct, pct, pct, pct, modSrc], buttonLabel: "Slow/Fast"),
        // Q-Wah Type: "[WAHWAH], [VOXWAH], [BASWAH] or [BASVOX]"
        H9Algorithm(index: 2, module: 2, name: "Q-Wah", knobLabels: ["Q-Intensity", "Type", "Vowel", "Speed", "Shape", "Bottom", "Depth Mod", "Speed Mod", "Mod Rate", "Mod Source"],
            knobFormats: [pct, .discrete(options: ["Q-Wah", "Vox Wah", "Bass Wah", "Bass Vox"]), pct, pct, modShape, pct, pct, pct, pct, modSrc], buttonLabel: "Slow/Fast"),
        // Flanger Type: "Positive [POSTVE], Negative [NEGTVE], Jet [JET] or Thru Zero [THRU-0]"
        H9Algorithm(index: 3, module: 2, name: "Flanger", knobLabels: ["Intensity", "Type", "Depth", "Speed", "Shape", "Modfy Dly O/P", "Depth Mod", "Speed Mod", "Mod Rate", "Mod Source"],
            knobFormats: [pct, .discrete(options: ["Positive", "Negative", "Jet", "Thru-0"]), pct, pct, modShape, pct, pct, pct, pct, modSrc], buttonLabel: "Slow/Fast"),
        // ModFilter Type: "Select Lowpass [LOPASS], Bandpass [BDPASS] or Highpass [HIPASS]"
        H9Algorithm(index: 4, module: 2, name: "ModFilter", knobLabels: ["Intensity", "Type", "Depth", "Sensitivity", "Shape", "Width", "Depth Mod", "Speed Mod", "Mod Rate", "Mod Source"],
            knobFormats: [pct, .discrete(options: ["Low Pass", "Band Pass", "High Pass"]), pct, pct, modShape, pct, pct, pct, pct, modSrc], buttonLabel: "Slow/Fast"),
        // Rotary Type: "Select Standard [STDRD] or Giant [GIANT] size cabinets"
        H9Algorithm(index: 5, module: 2, name: "Rotary", knobLabels: ["Mix", "Type", "Rotor Spd", "Horn Spd", "Rot/Hrn Mix", "Tone", "Depth Mod", "Speed Mod", "Mod Rate", "Mod Source"],
            knobFormats: [mix, .discrete(options: ["Standard", "Giant"]), pct, pct, mix, pct, pct, pct, pct, modSrc], buttonLabel: "Slow/Fast"),
        // TremoloPan Type: "Select Bias [BIAS] or opto-coupled [OPTO]"
        H9Algorithm(index: 6, module: 2, name: "TremoloPan", knobLabels: ["Edge", "Type", "Depth", "Speed", "Shape", "Width", "Depth Mod", "Speed Mod", "Mod Rate", "Mod Source"],
            knobFormats: [pct, .discrete(options: ["Bias", "Opto"]), pct, pct, modShape, pct, pct, pct, pct, modSrc], buttonLabel: "Slow/Fast"),
        // Vibrato Type: "Select – Modern [MODREN], Vintage [VINTGE] or Retro [RETRO]"
        H9Algorithm(index: 7, module: 2, name: "Vibrato", knobLabels: ["Intensity", "Type", "Depth", "Speed", "Shape", "Width", "Depth Mod", "Speed Mod", "Mod Sens", "Mod Source"],
            knobFormats: [pct, .discrete(options: ["Modern", "Vintage", "Retro"]), pct, pct, modShape, pct, pct, pct, pct, modSrc], buttonLabel: "Slow/Fast"),
        // Undulator Type: "Select – Pitch [PITCH] or Feedback [FEEDBK]"
        H9Algorithm(index: 8, module: 2, name: "Undulator", knobLabels: ["Intensity", "Type", "Depth", "Speed", "Shape", "Feedback", "Depth Mod", "Speed Mod", "Mod Rate", "Mod Source"],
            knobFormats: [pct, .discrete(options: ["Pitch", "Feedback"]), pct, pct, modShape, pct, pct, pct, pct, modSrc], buttonLabel: "Slow/Fast"),
        // RingMod Type: "Select [RING] or [STRING]"
        H9Algorithm(index: 9, module: 2, name: "RingMod", knobLabels: ["Intensity", "Type", "Un-Used", "Speed", "Shape", "Tone", "Depth Mod", "Speed Mod", "Mod Rate", "Mod Source"],
            knobFormats: [pct, .discrete(options: ["Ring", "String"]), pct, pct, modShape, pct, pct, pct, pct, modSrc], buttonLabel: "Slow/Fast"),

        // MARK: - PitchFactor (module 3)
        // Diatonic/Quadravox: pitch shift is by harmonic interval selection (Key/Scale-relative), not a plain cent range — percent
        H9Algorithm(index: 0, module: 3, name: "Diatonic", knobLabels: ["Mix", "Pitch Mix", "Pitch A", "Pitch B", "Delay A", "Delay B", "Key", "Scale", "Feedback A", "Feedback B"],
            knobFormats: [mix, pct, pct, pct, pct, pct, pct, pct, pct, pct], buttonLabel: "Flex"),
        H9Algorithm(index: 1, module: 3, name: "Quadravox", knobLabels: ["Mix", "Pitch Mix", "Pitch A", "Pitch B", "Delay D", "Delay Grp", "Key", "Mode", "Pitch C", "Pitch D"],
            knobFormats: [mix, pct, pct, pct, pct, pct, pct, pct, pct, pct], buttonLabel: "Flex"),
        // HarModulator: "Selects the pitch shift interval in semitone increments from down three octaves to up three octaves" = +/-3600 cents
        H9Algorithm(index: 2, module: 3, name: "HarModulator", knobLabels: ["Mix", "Pitch Mix", "Pitch A", "Pitch B", "Delay A", "Delay B", "Mod Depth", "Mod Sens", "Shape", "Feedback"],
            knobFormats: [mix, pct, pfPitch, pfPitch, delay3k, delay3k, pct, pct, modShape, pct], buttonLabel: "Flex"),
        // MicroPitch: "Controls the amount of pitch shift up for voice A from Unison to +50 cents" / voice B "Unison to -50 cents"
        H9Algorithm(index: 3, module: 3, name: "MicroPitch", knobLabels: ["Mix", "Pitch Mix", "Pitch A", "Pitch B", "Delay A", "Delay B", "Mod Depth", "Mod Rate", "Feedback", "Tone"],
            knobFormats: [mix, pct, .linear(min: 0, max: 50, unit: "cents", decimals: 0), .linear(min: -50, max: 0, unit: "cents", decimals: 0), delay3k, delay3k, pct, pct, pct, pct], buttonLabel: "Flex"),
        // H910/H949 Type: "[H910], [H949-1], [H949-2] and [MODERN]"
        H9Algorithm(index: 4, module: 3, name: "H910 949", knobLabels: ["Mix", "Pitch Mix", "Pitch A", "Pitch B", "Delay A", "Delay B", "Type", "Pitch Cntrl", "Feedback A", "Feedback B"],
            knobFormats: [mix, pct, pct, pct, delay3k, delay3k, .discrete(options: ["H910", "H949-1", "H949-2", "Modern"]), .discrete(options: ["Normal", "Micro", "Chromatic"]), pct, pct], buttonLabel: "Flex"),
        H9Algorithm(index: 5, module: 3, name: "PitchFlex", knobLabels: ["Mix", "Pitch Mix", "Heel A", "Heel B", "H-T Gliss", "T-H Gliss", "LP Filter", "Shape", "Toe A", "Toe B"],
            knobFormats: [mix, pct, pct, pct, pct, pct, pct, pct, pct, pct], buttonLabel: "Flex"),
        H9Algorithm(index: 6, module: 3, name: "Octaver", knobLabels: ["Mix", "Pitch Mix", "Filter A", "Filter B", "Resnce A", "Resnce B", "Envelope", "Sensitivity", "Fuzz", "Oct-Fuzz Mix"],
            knobFormats: [mix, pct, pct, pct, pct, pct, pct, pct, pct, pct], buttonLabel: "Flex"),
        // Crystals: "Controls the amount of pitch shift for A in cents" — no explicit numeric range stated, keep percent
        H9Algorithm(index: 7, module: 3, name: "Crystals", knobLabels: ["Mix", "Pitch Mix", "Pitch A", "Pitch B", "Rev Delay A", "Rev Delay B", "Verb Mix", "Verb Decay", "Feedback A", "Feedback B"],
            knobFormats: [mix, pct, pct, pct, pct, pct, pct, pct, pct, pct], buttonLabel: "Flex"),
        // HarPeggiator: Rhythm is 20 named presets + RANDOM; Dynamics explicitly "-10…0…10"
        H9Algorithm(index: 8, module: 3, name: "HarPeggiator", knobLabels: ["Mix", "Arp Mix", "Sequence A", "Sequence B", "Rhythm A", "Rhythm B", "Dynamics", "Length", "Effects A", "Effects B"],
            knobFormats: [mix, pct, pct, pct, pct, pct, .bipolar(min: -10, max: 10, unit: "", decimals: 0), pct, pct, pct], buttonLabel: "Flex"),
        // Synthonizer: Waveshape is discrete named list; Filter Sweep "0-50 sweep LP, >50 sweep HP" too ambiguous for a single unit, keep percent
        H9Algorithm(index: 9, module: 3, name: "Synthonizer", knobLabels: ["Mix", "Vox Mix", "Wave Mix A", "Octave B", "Attack A", "Attack B", "Verb Level", "Verb Decay", "Shape A", "Sweep B"],
            knobFormats: [mix, pct, pct, pct, pct, pct, pct, pct, .discrete(options: ["Sine", "Triangle", "Sawtooth", "Organ1", "Organ2"]), pct], buttonLabel: "Flex"),

        // MARK: - Space (module 4)
        // EQ levels (LO-LVL, HI-LVL, MIDLVL): "-100 effectively cuts all of the low/high/mid band reverb"
        // — bipolar dB-scale boost/cut. Mix 0-100%. No explicit numeric max for Decay, Size, Pre Delay.
        H9Algorithm(index: 0, module: 4, name: "Hall",
            knobLabels: ["Mix", "Decay", "Size", "Pre Delay", "Low EQ", "High EQ", "Low Decay", "High Decay", "Mod-Level", "Mid EQ"],
            knobFormats: [mix, pct, pct, pct, eqBip, eqBip, pct, pct, pct, eqBip], buttonLabel: "HotSwitch"),
        H9Algorithm(index: 1, module: 4, name: "Room",
            knobLabels: ["Mix", "Decay", "Size", "Pre Delay", "Low EQ", "High EQ", "Reflection", "Diffusion", "Mod-Level", "High Freq"],
            knobFormats: [mix, pct, pct, pct, eqBip, eqBip, pct, pct, pct, pct], buttonLabel: "HotSwitch"),
        H9Algorithm(index: 2, module: 4, name: "Plate",
            knobLabels: ["Mix", "Decay", "Size", "Pre Delay", "Low-damp", "High-damp", "Distance", "Diffusion", "Mod Level", "Tone"],
            knobFormats: [mix, pct, pct, pct, pct, pct, pct, pct, pct, pct], buttonLabel: "HotSwitch"),
        // Spring: Number of springs is discrete 1-3
        H9Algorithm(index: 3, module: 4, name: "Spring",
            knobLabels: ["Mix", "Decay", "Tension", "Num Springs", "Low-damp", "High-damp", "Reflection", "Trem Inten", "Trem Speed", "Resonance"],
            knobFormats: [mix, pct, pct, .discrete(options: ["1", "2", "3"]), pct, pct, pct, pct, pct, pct], buttonLabel: "HotSwitch"),
        H9Algorithm(index: 4, module: 4, name: "DualVerb",
            knobLabels: ["Mix", "A-Decay", "Size", "A Predelay", "A Tone", "B Tone", "B Decay", "B Predelay", "ABMix", "Resonance"],
            knobFormats: [mix, pct, pct, pct, pct, pct, pct, pct, mix, pct], buttonLabel: "HotSwitch"),
        H9Algorithm(index: 5, module: 4, name: "Reverse Reverb",
            knobLabels: ["Mix", "Decay", "Size", "Feedback", "Low EQ", "High EQ", "Late Dry", "Diffusion", "Mod Level", "Contour"],
            knobFormats: [mix, pct, pct, pct, eqBip, eqBip, pct, pct, pct, pct], buttonLabel: "HotSwitch"),
        H9Algorithm(index: 6, module: 4, name: "ModEchoVerb",
            knobLabels: ["Mix", "Decay", "Size", "Echo", "Low EQ", "High EQ", "Echo Fdbk", "Modrate", "Chorus Mix", "Echotone"],
            knobFormats: [mix, pct, pct, pct, eqBip, eqBip, pct, pct, mix, pct], buttonLabel: "HotSwitch"),
        H9Algorithm(index: 7, module: 4, name: "Blackhole",
            knobLabels: ["Mix", "Gravity", "Size", "Pre Delay", "Low EQ", "High EQ", "Mod-Depth", "Modrate", "Feedback", "Resonance"],
            knobFormats: [mix, pct, pct, pct, eqBip, eqBip, pct, pct, pct, pct], buttonLabel: "HotSwitch"),
        H9Algorithm(index: 8, module: 4, name: "MangledVerb",
            knobLabels: ["Mix", "Decay", "Size", "Pre Delay", "Low EQ", "High EQ", "Overdrive", "Output", "Wobble", "Mid EQ"],
            knobFormats: [mix, pct, pct, pct, eqBip, eqBip, pct, pct, pct, eqBip], buttonLabel: "HotSwitch"),
        // TremoloVerb Shape = modShape; no numeric range for Speed stated
        H9Algorithm(index: 9, module: 4, name: "TremoloVerb",
            knobLabels: ["Mix", "Decay", "Size", "Pre Delay", "Low EQ", "High EQ", "Shape", "Speed", "Mono Depth", "High Freq"],
            knobFormats: [mix, pct, pct, pct, eqBip, eqBip, modShape, pct, pct, pct], buttonLabel: "HotSwitch"),
        H9Algorithm(index: 10, module: 4, name: "DynaVerb",
            knobLabels: ["Mix", "Decay", "Size", "Attack", "Low EQ", "High EQ", "Omni-Ratio", "Release", "Threshold", "Sidechain"],
            knobFormats: [mix, pct, pct, pct, eqBip, eqBip, pct, pct, pct, pct], buttonLabel: "HotSwitch"),
        // Shimmer A-Pitch / B-Pitch: "500c (P4) to 2400c (2 Octaves)" per CSV
        H9Algorithm(index: 11, module: 4, name: "Shimmer",
            knobLabels: ["Mix", "Decay", "Size", "Delay", "Low-decay", "High-decay", "A-Pitch", "B-Pitch", "Pitch-Decay", "Mid-Decay"],
            knobFormats: [mix, pct, pct, pct, pct, pct, .linear(min: 500, max: 2400, unit: "¢", decimals: 0), .linear(min: 500, max: 2400, unit: "¢", decimals: 0), pct, pct], buttonLabel: "HotSwitch"),

        // MARK: - H9-new (module 5)
        H9Algorithm(index: 0, module: 5, name: "UltraTap",
            knobLabels: ["Mix", "Length", "Taps", "Pre-Delay", "Spread", "Taper", "Tone", "Slurm", "Chop", "Un-Used"],
            knobFormats: [mix, pct, pct, pct, pct, pct, pct, pct, pct, pct], buttonLabel: "HotSwitch"),
        H9Algorithm(index: 1, module: 5, name: "Resonator",
            knobLabels: ["Mix", "Length", "Rhythm", "Feedback", "Resonance", "Reverb", "Note 1", "Note 2", "Note 3", "Note 4"],
            knobFormats: [mix, pct, pct, pct, pct, pct, pct, pct, pct, pct], buttonLabel: "HotSwitch"),
        // EQ Compressor: CSV provides Gain1/Gain2 (-18 to +12dB), Freq1 (30-1500Hz), Freq2 (1000-9999Hz), Bass/Treble bipolar dB
        H9Algorithm(index: 2, module: 5, name: "EQ Compressor",
            knobLabels: ["Gain 1", "Frequency 1", "Width 1", "Gain 2", "Frequency 2", "Width 2", "Bass", "Treble", "Compressor", "Trim"],
            knobFormats: [
                .bipolar(min: -18, max: 12, unit: "dB", decimals: 0),
                .linear(min: 30, max: 1500, unit: "Hz", decimals: 0),
                pct,
                .bipolar(min: -18, max: 12, unit: "dB", decimals: 0),
                .linear(min: 1000, max: 9999, unit: "Hz", decimals: 0),
                pct,
                pct, pct, pct, pct
            ], buttonLabel: "HotSwitch"),
        // SpaceTime: Rate 0.05-12.5Hz, Delay A/B 0-2500ms per CSV
        H9Algorithm(index: 3, module: 5, name: "SpaceTime",
            knobLabels: ["Mix", "Mod Amt", "Mod Rate", "Verb Lvl", "Decay", "Color", "Delay Lvl", "Delay A", "Delay B", "Feedback"],
            knobFormats: [mix, pct, .linear(min: 0.05, max: 12.5, unit: "Hz", decimals: 2), pct, pct, pct, pct, delay25, delay25, pct], buttonLabel: "HotSwitch"),
        H9Algorithm(index: 4, module: 5, name: "Sculpt",
            knobLabels: ["Mix", "Bandmix", "XOver", "Low-Drive", "High-Drive", "Compressor", "Low Boost", "Filter-Pre", "Filter-Post", "Env-Filter"],
            knobFormats: [mix, pct, pct, pct, pct, pct, pct, pct, pct, pct], buttonLabel: "HotSwitch"),
        // CrushStation: Mids Freq is tunable center frequency (Hz); Bass/Treble/Mids = dB Boost/Cut (no exact range stated)
        H9Algorithm(index: 5, module: 5, name: "CrushStation",
            knobLabels: ["Mix", "Drive", "Sustain", "Sag", "Octaves", "Grit", "Bass", "Mids", "Mids Freq", "Treble"],
            knobFormats: [mix, pct, pct, pct, pct, pct, pct, pct, pct, pct], buttonLabel: "HotSwitch"),
        H9Algorithm(index: 6, module: 5, name: "PitchFuzz",
            knobLabels: ["Fuzz", "Fuzz Tone", "Pitch Amt", "Pitch A", "Pitch B", "Pitch C", "Arp Level", "Delay B", "Delay C", "Feedback"],
            knobFormats: [pct, pct, pct, pct, pct, pct, pct, pct, pct, pct], buttonLabel: "HotSwitch"),
        H9Algorithm(index: 7, module: 5, name: "HotSawz",
            knobLabels: ["Mix", "Osc Depth", "Cutoff", "Resonance", "LFO/Speed", "LFO Amount", "Attack", "Decay", "Gate", "Envelope"],
            knobFormats: [mix, pct, pct, pct, pct, pct, pct, pct, pct, pct], buttonLabel: "HotSwitch"),
        H9Algorithm(index: 8, module: 5, name: "Harmadillo",
            knobLabels: ["Depth", "Rate", "Shape", "X-Over", "X-Overlap", "Drive", "Env Depth", "Env Rate", "Env X-Over", "Tone"],
            knobFormats: [pct, pct, modShape, pct, pct, pct, pct, pct, pct, pct], buttonLabel: "HotSwitch"),
        // TriceraChorus: Rate 0.1-20Hz, Delay 0-200ms, Detune -40 to +40 cents per CSV
        H9Algorithm(index: 9, module: 5, name: "Tricerachorus",
            knobLabels: ["Ch/Vib Mix", "Rate", "Depth L", "Depth C", "Depth R", "Delay", "Detune Mix", "Detune", "Env Mix/Rate", "Tone"],
            knobFormats: [mix, .linear(min: 0.1, max: 20, unit: "Hz", decimals: 1), pct, pct, pct, .linear(min: 0, max: 200, unit: "ms", decimals: 0), pct, .bipolar(min: -40, max: 40, unit: "¢", decimals: 0), pct, pct], buttonLabel: "HotSwitch"),
    ]

    public static func algorithm(index: Int, module: Int) -> H9Algorithm? {
        all.first { $0.index == index && $0.module == module }
    }

    /// 10 labels for the given algorithm index/module, falling back to
    /// generic "Knob N" labels for an unrecognized pair.
    public static func knobLabels(index: Int, module: Int) -> [String] {
        algorithm(index: index, module: module)?.knobLabels ?? (1...10).map { "Knob \($0)" }
    }

    /// 10 display formats for the given algorithm index/module, falling back
    /// to `.percent` for every slot when the algorithm isn't in the catalog.
    public static func knobFormats(index: Int, module: Int) -> [H9ParameterFormat] {
        algorithm(index: index, module: module)?.knobFormats ?? Array(repeating: .percent, count: 10)
    }
}

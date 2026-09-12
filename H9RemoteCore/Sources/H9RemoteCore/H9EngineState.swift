import Foundation

/// Single source of truth for the H9 Remote's control state: knob values,
/// PSW, expression, tempo, output gain, modfactor, algorithm number, preset
/// name, and MIDI/SysEx configuration. AUParameter observers read/write this
/// model; the MIDI codec reads/writes it when translating to/from CC and
/// SysEx bytes.
public final class H9EngineState {
    // Automatable parameters (mirrors H9Parameter cases).
    public var knobValues: [Double] = Array(repeating: 0, count: H9MIDICodec.knobCount)
    public var performanceSwitch: Bool = false
    public var expression: Double = 0
    public var tempo: Double = 120
    public var tempoEnabled: Bool = false
    public var outputGain: Double = 0
    public var modfactorFastSlow: Bool = false
    public var algorithmNumber: Int = 0
    public var moduleNumber: Int = 4 // default Space, matches H9AlgorithmCatalog's Hall (index 0, module 4)

    // Not AU-automatable, but part of the original device's control surface.
    public var presetNumber: Int = 0 // 0 = the H9's temporary "audition" slot
    public var presetName: String = ""

    // MIDI/SysEx configuration (matches the bpatcher's numboxes; not parameters).
    public var midiTxChannel: UInt8 = 1
    public var midiRxChannel: UInt8 = 1
    public var sysexID: UInt8 = 1
    public var knobCCOffset: UInt8 = 22
    public var pswCCNumber: UInt8 = 71
    public var expressionCCNumber: UInt8 = 11

    // v1 simplification: identity expression map (0...1) and no PSW mapping.
    public var knobExpressionMin: [Double] = Array(repeating: 0, count: H9MIDICodec.knobCount)
    public var knobExpressionMax: [Double] = Array(repeating: 1, count: H9MIDICodec.knobCount)
    public var knobPerformanceSwitchMap: [Bool] = Array(repeating: false, count: H9MIDICodec.knobCount)

    public let connectionGuard = H9ConnectionGuard()

    public init() {}

    public func value(for parameter: H9Parameter) -> Double {
        switch parameter {
        case .knob1, .knob2, .knob3, .knob4, .knob5,
             .knob6, .knob7, .knob8, .knob9, .knob10:
            return knobValues[parameter.knobIndex! - 1]
        case .performanceSwitch: return performanceSwitch ? 1 : 0
        case .expression: return expression
        case .tempo: return tempo
        case .tempoEnable: return tempoEnabled ? 1 : 0
        case .outputGain: return outputGain
        case .modfactorFastSlow: return modfactorFastSlow ? 1 : 0
        case .algorithmNumber: return Double(algorithmNumber)
        case .moduleNumber: return Double(moduleNumber)
        }
    }

    public func setValue(_ value: Double, for parameter: H9Parameter) {
        switch parameter {
        case .knob1, .knob2, .knob3, .knob4, .knob5,
             .knob6, .knob7, .knob8, .knob9, .knob10:
            knobValues[parameter.knobIndex! - 1] = value
        case .performanceSwitch: performanceSwitch = value != 0
        case .expression: expression = value
        case .tempo: tempo = value
        case .tempoEnable: tempoEnabled = value != 0
        case .outputGain: outputGain = value
        case .modfactorFastSlow: modfactorFastSlow = value != 0
        case .algorithmNumber: algorithmNumber = Int(value)
        case .moduleNumber: moduleNumber = Int(value)
        }
    }

    // MARK: - MIDI CC integration

    /// Applies an incoming MIDI CC to engine state. Returns true if the CC
    /// was recognized and applied (matching the MIDI RX channel filter).
    @discardableResult
    public func applyIncomingCC(channel: UInt8, ccNumber: UInt8, value: UInt8) -> Bool {
        guard channel == midiRxChannel else { return false }
        switch H9MIDICodec.role(
            ccNumber: ccNumber,
            knobCCOffset: knobCCOffset,
            pswCCNumber: pswCCNumber,
            expressionCCNumber: expressionCCNumber
        ) {
        case .knobCoarse(let index):
            pendingCoarse[index] = value
            tryAssembleKnob(index)
            return true
        case .knobFine(let index):
            pendingFine[index] = value
            tryAssembleKnob(index)
            return true
        case .performanceSwitch:
            performanceSwitch = value >= 64
            return true
        case .expression:
            expression = H9MIDICodec.decodeSingleCC(value)
            return true
        case .other:
            return false
        }
    }

    private var pendingCoarse: [Int: UInt8] = [:]
    private var pendingFine: [Int: UInt8] = [:]

    private func tryAssembleKnob(_ index: Int) {
        guard let coarse = pendingCoarse[index], let fine = pendingFine[index] else { return }
        knobValues[index - 1] = H9MIDICodec.decodeKnob(coarseValue: coarse, fineValue: fine)
    }

    /// Encodes the current value of a knob as its coarse+fine CC pair for
    /// transmission.
    public func outgoingKnobCC(index: Int) -> H9MIDICodec.KnobCCPair {
        H9MIDICodec.encodeKnob(
            knobIndex: index,
            normalizedValue: knobValues[index - 1],
            knobCCOffset: knobCCOffset
        )
    }

    // MARK: - SysEx integration

    /// Builds a full program dump from current engine state.
    public func makeProgramDump() -> H9ProgramDump {
        H9ProgramDump(
            presetNumber: presetNumber,
            algorithmNumber: algorithmNumber,
            moduleNumber: moduleNumber,
            knobValues: knobValues,
            expression: expression,
            knobExpressionMin: knobExpressionMin,
            knobExpressionMax: knobExpressionMax,
            knobPerformanceSwitchMap: knobPerformanceSwitchMap,
            tempo: tempo,
            tempoEnabled: tempoEnabled,
            outputGain: outputGain,
            modfactorFastSlow: modfactorFastSlow,
            xAssignment: 0,
            yAssignment: 0,
            zAssignment: 0,
            presetName: presetName
        )
    }

    /// Applies a parsed program dump to engine state (used after a
    /// "sync from hardware" pull).
    public func apply(_ dump: H9ProgramDump) {
        presetNumber = dump.presetNumber
        algorithmNumber = dump.algorithmNumber
        moduleNumber = dump.moduleNumber
        knobValues = dump.knobValues
        expression = dump.expression
        knobExpressionMin = dump.knobExpressionMin
        knobExpressionMax = dump.knobExpressionMax
        knobPerformanceSwitchMap = dump.knobPerformanceSwitchMap
        tempo = dump.tempo
        tempoEnabled = dump.tempoEnabled
        outputGain = dump.outputGain
        modfactorFastSlow = dump.modfactorFastSlow
        presetName = dump.presetName
    }

    /// Builds the SysEx bytes for a "push to hardware" full dump.
    public func makePushSysEx() -> [UInt8] {
        let text = makeProgramDump().serializeText()
        let bytes = Array(text.utf8)
        return H9SysExCodec.wrapProgramDump(bytes, sysexID: sysexID)
    }

    /// Builds the SysEx bytes for a "sync from hardware" pull request.
    public func makePullRequestSysEx() -> [UInt8] {
        H9SysExCodec.getCurrentPresetRequest(sysexID: sysexID)
    }
}

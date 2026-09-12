import Combine
import Foundation
import H9RemoteCore

/// Owns the engine state, MIDI connection, and hardware-detection state
/// machine for the standalone control app.
final class H9StandaloneViewModel: ObservableObject {
    let midi = H9MIDIConnection()
    private let engineState = H9EngineState()

    @Published var knobValues: [Double] = Array(repeating: 0, count: H9MIDICodec.knobCount)
    @Published var performanceSwitch: Bool = false
    @Published var expression: Double = 0
    @Published var tempo: Double = 120
    @Published var tempoEnabled: Bool = false
    @Published var outputGain: Double = 0
    @Published var modfactorFastSlow: Bool = false
    @Published var algorithmNumber: Int = 0
    @Published var moduleNumber: Int = 4
    @Published var presetName: String = ""
    @Published var connectionCheckStatus: H9ConnectionCheckStatus = .unknown
    /// Which preset slot "Save Preset" targets next — chosen explicitly by
    /// the user at save time, independent of AU automation or hardware
    /// sync (matches how H9 Control's own "Save to Device" flow works).
    @Published var saveSlot: Int = 1

    private var detectionTimeoutTimer: Timer?
    private static let detectionTimeout: TimeInterval = 2.0

    init() {
        midi.onMessageReceived = { [weak self] bytes in
            self?.handleIncoming(bytes)
        }
    }

    // MARK: - Outgoing controls

    func setKnob(index: Int, value: Double) {
        knobValues[index - 1] = value
        engineState.knobValues[index - 1] = value
        let pair = engineState.outgoingKnobCC(index: index)
        let channel = engineState.midiTxChannel - 1
        midi.send([0xB0 | channel, pair.coarseCC, pair.coarseValue])
        midi.send([0xB0 | channel, pair.fineCC, pair.fineValue])
    }

    func setPerformanceSwitch(_ isOn: Bool) {
        performanceSwitch = isOn
        engineState.performanceSwitch = isOn
        let channel = engineState.midiTxChannel - 1
        midi.send([0xB0 | channel, engineState.pswCCNumber, isOn ? 127 : 0])
    }

    func setExpression(_ value: Double) {
        expression = value
        engineState.expression = value
        let channel = engineState.midiTxChannel - 1
        let ccValue = H9MIDICodec.encodeSingleCC(normalizedValue: value)
        midi.send([0xB0 | channel, engineState.expressionCCNumber, ccValue])
    }

    func pushCurrentStateToHardware() {
        applyPublishedValuesToEngineState()
        midi.send(engineState.makePushSysEx())
    }

    func requestSyncFromHardware() {
        midi.send(engineState.makePullRequestSysEx())
    }

    /// Permanently writes the current state to preset slot `slot` (1...99)
    /// on the H9 — unlike `pushCurrentStateToHardware()`'s default slot 0
    /// (a temporary audition area), a nonzero slot overwrites that preset
    /// directly with no undo.
    func savePreset(toSlot slot: Int) {
        engineState.presetNumber = slot
        pushCurrentStateToHardware()
    }

    /// The H9 has no standalone "switch algorithm" MIDI message — changing
    /// algorithms only happens by pushing a full preset dump with the new
    /// algorithm index/module (the sanctioned workflow; see
    /// H9AlgorithmCatalog's doc comment).
    func setAlgorithm(index: Int, module: Int) {
        algorithmNumber = index
        moduleNumber = module
        engineState.algorithmNumber = index
        engineState.moduleNumber = module
        pushCurrentStateToHardware()
    }

    // MARK: - Hardware detection

    func checkConnection() {
        connectionCheckStatus = .checking
        detectionTimeoutTimer?.invalidate()
        midi.send(engineState.makePullRequestSysEx())
        detectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: Self.detectionTimeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard self?.connectionCheckStatus == .checking else { return }
                self?.connectionCheckStatus = .notDetected
            }
        }
    }

    // MARK: - Incoming MIDI

    private func handleIncoming(_ bytes: [UInt8]) {
        if H9DeviceDetection.isDetectionResponse(bytes, sysexID: engineState.sysexID) {
            detectionTimeoutTimer?.invalidate()
            connectionCheckStatus = .detected
        }

        if bytes.first == H9SysExCodec.sysExStart, bytes.last == H9SysExCodec.sysExEnd {
            if case .programDumpPayload(let payload) = H9SysExCodec.parse(bytes, expectedSysexID: engineState.sysexID),
               let dump = try? H9ProgramDump.parse(text: String(decoding: payload, as: UTF8.self)) {
                engineState.apply(dump)
                syncPublishedValuesFromEngineState()
            }
            return
        }

        guard bytes.count == 3 else { return }
        let channel = (bytes[0] & 0x0F) + 1
        if engineState.applyIncomingCC(channel: channel, ccNumber: bytes[1], value: bytes[2]) {
            syncPublishedValuesFromEngineState()
        }
    }

    private func syncPublishedValuesFromEngineState() {
        knobValues = engineState.knobValues
        performanceSwitch = engineState.performanceSwitch
        expression = engineState.expression
        tempo = engineState.tempo
        tempoEnabled = engineState.tempoEnabled
        outputGain = engineState.outputGain
        modfactorFastSlow = engineState.modfactorFastSlow
        algorithmNumber = engineState.algorithmNumber
        moduleNumber = engineState.moduleNumber
        presetName = engineState.presetName
    }

    private func applyPublishedValuesToEngineState() {
        engineState.knobValues = knobValues
        engineState.performanceSwitch = performanceSwitch
        engineState.expression = expression
        engineState.tempo = tempo
        engineState.tempoEnabled = tempoEnabled
        engineState.outputGain = outputGain
        engineState.modfactorFastSlow = modfactorFastSlow
        engineState.presetName = presetName
    }
}

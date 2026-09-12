import AVFoundation
import AudioToolbox
import H9RemoteCore

/// AUv3 MIDI Processor for the H9 Remote. No audio DSP is performed — audio
/// is passed through unchanged, matching the original Max device's
/// `plugin~`/`plugout~` passthrough. All control happens via MIDI CC and
/// SysEx, exchanged through the host's MIDI event list (this extension does
/// not open CoreMIDI ports directly to hardware; see H9Remote/ContentView
/// for the routing note shown to the user).
final class H9AudioUnit: AUAudioUnit {
    private let engineState = H9EngineState()
    private(set) var parameterTreeBuilder: H9ParameterTreeBuilder!

    private var inputBusArray: AUAudioUnitBusArray!
    private var outputBusArray: AUAudioUnitBusArray!

    /// Outgoing CC/SysEx bytes queued by parameter changes or sync actions,
    /// drained into the host-provided MIDI output block on the next render.
    private var pendingMIDIOut: [[UInt8]] = []
    private let pendingMIDIOutLock = NSLock()

    /// Called whenever `connectionCheckStatus` changes, so the UI can show a
    /// real hardware-detection light (mirrors the standalone app's
    /// `H9StandaloneViewModel.checkConnection()`/`connectionCheckStatus`).
    var onConnectionStatusChanged: ((H9ConnectionCheckStatus) -> Void)?
    /// Called after `engineState` is updated from an incoming SysEx dump or
    /// CC message. `H9RemoteViewModel`'s SwiftUI view is bound to its own
    /// `@Published` properties, not directly to the `AUParameterTree` —
    /// `syncTreeFromEngineState()` alone only updates the tree (visible to
    /// host automation), so without this callback, hardware-originated
    /// changes ("Sync from Hardware", live knob turns on the pedal) were
    /// applied internally but never appeared in the plugin's own UI.
    var onHardwareStateChanged: (() -> Void)?
    private var connectionCheckStatus: H9ConnectionCheckStatus = .unknown {
        didSet { onConnectionStatusChanged?(connectionCheckStatus) }
    }
    private var detectionTimeoutTimer: Timer?
    private static let detectionTimeout: TimeInterval = 2.0

    override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let inputBus = try AUAudioUnitBus(format: format)
        let outputBus = try AUAudioUnitBus(format: format)
        inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [inputBus])
        outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])

        parameterTreeBuilder = H9ParameterTreeBuilder(engineState: engineState)
        parameterTreeBuilder.onParameterChanged = { [weak self] parameter, _ in
            self?.enqueueOutgoingMIDI(for: parameter)
        }
    }

    override var inputBusses: AUAudioUnitBusArray { inputBusArray }
    override var outputBusses: AUAudioUnitBusArray { outputBusArray }
    override var parameterTree: AUParameterTree? {
        get { parameterTreeBuilder.tree }
        set { }
    }

    // MARK: - MIDI Processor requirements

    override var midiOutputNames: [String] { ["H9 Remote Out"] }

    private var midiOutputEventBlockStorage: AUMIDIOutputEventBlock?
    override var midiOutputEventBlock: AUMIDIOutputEventBlock? {
        get { midiOutputEventBlockStorage }
        set { midiOutputEventBlockStorage = newValue }
    }

    // MARK: - Render (audio passthrough, MIDI in/out handling)

    override var internalRenderBlock: AUInternalRenderBlock {
        { [weak self] actionFlags, timestamp, frameCount, outputBusNumber, outputData, realtimeEventListHead, pullInputBlock in
            guard let self, let pullInputBlock else { return kAudioUnitErr_NoConnection }

            var inputFlags: AudioUnitRenderActionFlags = []
            let inputData = outputData
            let status = pullInputBlock(&inputFlags, timestamp, frameCount, 0, inputData)
            if status != noErr { return status }

            self.processRealtimeEvents(realtimeEventListHead, timestamp: timestamp)
            self.flushPendingMIDIOut(at: timestamp)

            return noErr
        }
    }

    private func processRealtimeEvents(_ eventListHead: UnsafePointer<AURenderEvent>?, timestamp: UnsafePointer<AudioTimeStamp>) {
        var event = eventListHead
        while let current = event {
            let header = current.pointee.head
            // Regular 1-3 byte MIDI (CC, etc.) and SysEx arrive as two
            // DIFFERENT event types (`.MIDI` vs `.midiSysEx`) despite
            // sharing the same `AUMIDIEvent` payload struct — checking only
            // `.MIDI` here meant every incoming SysEx reply from the H9
            // (program dumps, detection responses) was silently dropped by
            // the AU, even though outgoing SysEx worked fine. This is why
            // "Check Connection"/"Sync from Hardware" never completed when
            // hosted in a real DAW.
            if header.eventType == .MIDI || header.eventType == .midiSysEx {
                handleIncomingMIDI(Self.bytes(fromEventPointer: current))
            }
            event = UnsafePointer(header.next)
        }
    }

    /// `AUMIDIEvent.data` is imported into Swift as a fixed 3-byte tuple
    /// (mirroring the C header's `uint8_t data[3]`), but the header's own
    /// doc comment notes SysEx events carry more bytes than that inline
    /// field can hold — the host allocates the real payload immediately
    /// following the `AUMIDIEvent` struct's fixed header in the underlying
    /// `AURenderEvent` node (which is 296 bytes, much larger than
    /// `AUMIDIEvent`'s 24). Reading through a *copied-out* `.MIDI` value
    /// (`current.pointee.MIDI`) truncates to that 24-byte copy and loses
    /// everything past it — this must instead read straight from the
    /// original `AURenderEvent` pointer, computing `data`'s real byte
    /// offset and reading `length` bytes starting there, however long that
    /// is. Verified against a synthetic 10-byte payload before relying on
    /// it for real hardware SysEx.
    private static func bytes(fromEventPointer eventPtr: UnsafePointer<AURenderEvent>) -> [UInt8] {
        let byteCount = Int(eventPtr.pointee.MIDI.length)
        let dataOffset = MemoryLayout<AUMIDIEvent>.offset(of: \AUMIDIEvent.data)!
        let rawPtr = UnsafeRawPointer(eventPtr) + dataOffset
        return Array(UnsafeRawBufferPointer(start: rawPtr, count: byteCount))
    }

    private func handleIncomingMIDI(_ bytes: [UInt8]) {
        guard !bytes.isEmpty else { return }

        if bytes[0] == H9SysExCodec.sysExStart, bytes.last == H9SysExCodec.sysExEnd {
            if H9DeviceDetection.isDetectionResponse(bytes, sysexID: engineState.sysexID) {
                DispatchQueue.main.async { [weak self] in
                    self?.detectionTimeoutTimer?.invalidate()
                    self?.connectionCheckStatus = .detected
                }
            }
            switch H9SysExCodec.parse(bytes, expectedSysexID: engineState.sysexID) {
            case .programDumpPayload(let payload):
                let text = String(decoding: payload, as: UTF8.self)
                if let dump = try? H9ProgramDump.parse(text: text) {
                    engineState.apply(dump)
                    parameterTreeBuilder.syncTreeFromEngineState()
                    DispatchQueue.main.async { [weak self] in self?.onHardwareStateChanged?() }
                }
            case .getCurrentPresetRequest, .dumpAllPresetsRequest, .presetsDumpPayload, .unrecognized:
                break
            }
            return
        }

        guard bytes.count >= 3 else { return }
        let statusByte = bytes[0]
        let messageType = statusByte & 0xF0
        guard messageType == 0xB0 else { return } // Control Change
        let channel = (statusByte & 0x0F) + 1
        let ccNumber = bytes[1]
        let value = bytes[2]
        if engineState.applyIncomingCC(channel: channel, ccNumber: ccNumber, value: value) {
            parameterTreeBuilder.syncTreeFromEngineState()
            DispatchQueue.main.async { [weak self] in self?.onHardwareStateChanged?() }
        }
    }

    private func enqueueOutgoingMIDI(for parameter: H9Parameter) {
        let channel = engineState.midiTxChannel - 1
        var messages: [[UInt8]] = []

        switch parameter {
        case .knob1, .knob2, .knob3, .knob4, .knob5,
             .knob6, .knob7, .knob8, .knob9, .knob10:
            let pair = engineState.outgoingKnobCC(index: parameter.knobIndex!)
            messages.append([0xB0 | channel, pair.coarseCC, pair.coarseValue])
            messages.append([0xB0 | channel, pair.fineCC, pair.fineValue])
        case .performanceSwitch:
            let value: UInt8 = engineState.performanceSwitch ? 127 : 0
            messages.append([0xB0 | channel, engineState.pswCCNumber, value])
        case .expression:
            let value = H9MIDICodec.encodeSingleCC(normalizedValue: engineState.expression)
            messages.append([0xB0 | channel, engineState.expressionCCNumber, value])
        case .tempo, .tempoEnable, .outputGain, .modfactorFastSlow:
            // These are only transmitted as part of a full SysEx dump (see
            // pushCurrentStateToHardware), not as standalone real-time CCs,
            // matching the original device's compute_sysex trigger order.
            break
        case .algorithmNumber, .moduleNumber:
            // The H9 has no standalone "switch algorithm" MIDI message —
            // changing algorithms only happens by pushing a full preset
            // dump with the new algorithm index/module (the sanctioned
            // workflow; see H9AlgorithmCatalog's doc comment). Selecting a
            // new algorithm changes both fields, so both trigger a push;
            // two pushes in quick succession is harmless — the second just
            // supersedes the first with the same, now-complete state.
            pushCurrentStateToHardware()
            return
        }

        guard !messages.isEmpty else { return }
        pendingMIDIOutLock.lock()
        pendingMIDIOut.append(contentsOf: messages)
        pendingMIDIOutLock.unlock()
    }

    private func flushPendingMIDIOut(at timestamp: UnsafePointer<AudioTimeStamp>) {
        pendingMIDIOutLock.lock()
        let messages = pendingMIDIOut
        pendingMIDIOut.removeAll()
        pendingMIDIOutLock.unlock()

        guard !messages.isEmpty, let outputBlock = midiOutputEventBlockStorage else { return }
        for message in messages {
            message.withUnsafeBufferPointer { buffer in
                _ = outputBlock(AUEventSampleTimeImmediate, 0, buffer.count, buffer.baseAddress!)
            }
        }
    }

    // MARK: - Sync actions (invoked from the UI)

    /// "Push to hardware": sends a full computed SysEx program dump.
    func pushCurrentStateToHardware() {
        guard engineState.connectionGuard.canTransmit else { return }
        let bytes = engineState.makePushSysEx()
        queueRawSysEx(bytes)
    }

    /// "Sync from hardware": requests the current preset; the response is
    /// applied in `handleIncomingMIDI` when it arrives.
    func requestSyncFromHardware() {
        let bytes = engineState.makePullRequestSysEx()
        queueRawSysEx(bytes)
    }

    /// Sends a real hardware-detection query and arms a timeout, mirroring
    /// the standalone app's `H9StandaloneViewModel.checkConnection()`. A
    /// checksum-valid reply flips the status to `.detected` in
    /// `handleIncomingMIDI`; otherwise this flips to `.notDetected` after
    /// `detectionTimeout`.
    func checkConnection() {
        connectionCheckStatus = .checking
        detectionTimeoutTimer?.invalidate()
        queueRawSysEx(engineState.makePullRequestSysEx())
        detectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: Self.detectionTimeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard self?.connectionCheckStatus == .checking else { return }
                self?.connectionCheckStatus = .notDetected
            }
        }
    }

    /// Permanently writes the current state to preset slot `slot` (1...99)
    /// on the H9 — unlike `pushCurrentStateToHardware()`'s default slot 0
    /// (a temporary audition area), a nonzero slot overwrites that preset
    /// directly with no undo.
    func savePreset(toSlot slot: Int) {
        engineState.presetNumber = slot
        pushCurrentStateToHardware()
    }

    private func queueRawSysEx(_ bytes: [UInt8]) {
        pendingMIDIOutLock.lock()
        pendingMIDIOut.append(bytes)
        pendingMIDIOutLock.unlock()
    }
}

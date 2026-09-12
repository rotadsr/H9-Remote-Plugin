import SwiftUI
import AudioToolbox
import H9RemoteCore

/// SwiftUI control surface mirroring the original Max device's UI: 10 knob
/// dials, PSW, expression, tempo/tempo-enable, output gain, modfactor,
/// algorithm number readout, preset name field, and sync buttons.
struct H9RemoteView: View {
    @ObservedObject var viewModel: H9RemoteViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Preset Name", text: $viewModel.presetName)
                    .textFieldStyle(.roundedBorder)
                algorithmPicker
                Spacer()
                connectionIndicator
            }
            .h9SectionCard()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(1...10, id: \.self) { index in
                    H9KnobView(
                        value: viewModel.binding(forKnob: index),
                        label: knobLabels[index - 1],
                        accentColor: currentLineage.knobAccentColor,
                        format: knobFormats[index - 1]
                    )
                }
            }
            .h9SectionCard()

            HStack(spacing: 24) {
                Toggle("PSW", isOn: $viewModel.performanceSwitch)
                VStack(alignment: .leading) {
                    Text("Expression")
                    Slider(value: $viewModel.expression, in: 0...1)
                }
            }
            .h9SectionCard()

            HStack(spacing: 24) {
                Toggle("Tempo Enabled", isOn: $viewModel.tempoEnabled)
                VStack(alignment: .leading) {
                    Text("Tempo: \(Int(viewModel.tempo)) bpm")
                    Slider(value: $viewModel.tempo, in: 20...300)
                }
                VStack(alignment: .leading) {
                    Text("Output Gain: \(String(format: "%.1f", viewModel.outputGain)) dB")
                    Slider(value: $viewModel.outputGain, in: 0...12)
                }
                Toggle("Modfactor Fast", isOn: $viewModel.modfactorFastSlow)
            }
            .h9SectionCard()

            HStack(spacing: 16) {
                Button {
                    viewModel.requestSyncFromHardware()
                } label: {
                    Label("Sync from Hardware", systemImage: "arrow.triangle.2.circlepath")
                }
                Button {
                    viewModel.pushCurrentStateToHardware()
                } label: {
                    Label("Push to Hardware", systemImage: "arrow.up.circle")
                }
                Spacer()
                H9SavePresetControl(slot: $viewModel.saveSlot) { slot in
                    viewModel.savePreset(toSlot: slot)
                }
            }
            .h9SectionCard()
        }
        .padding(16)
        .preferredColorScheme(.dark)
    }

    private var currentLineage: H9PedalLineage {
        H9AlgorithmCatalog.algorithm(index: viewModel.algorithmNumber, module: viewModel.moduleNumber)?.lineage ?? .space
    }

    private var knobLabels: [String] {
        H9AlgorithmCatalog.knobLabels(index: viewModel.algorithmNumber, module: viewModel.moduleNumber)
    }

    private var knobFormats: [H9ParameterFormat] {
        H9AlgorithmCatalog.knobFormats(index: viewModel.algorithmNumber, module: viewModel.moduleNumber)
    }

    private var algorithmPicker: some View {
        Picker("Algorithm", selection: Binding(
            get: { H9AlgorithmCatalog.algorithm(index: viewModel.algorithmNumber, module: viewModel.moduleNumber) },
            set: { newValue in
                guard let newValue else { return }
                viewModel.setAlgorithm(index: newValue.index, module: newValue.module)
            }
        )) {
            ForEach(H9PedalLineage.allCases, id: \.self) { lineage in
                Section {
                    ForEach(H9AlgorithmCatalog.all.filter { $0.lineage == lineage }) { algorithm in
                        Text(algorithm.name).tag(Optional(algorithm))
                    }
                } header: {
                    Label(lineage.rawValue, systemImage: "circle.fill")
                        .foregroundStyle(lineage.accentColor)
                }
            }
        }
        .labelsHidden()
        .frame(maxWidth: 220)
    }

    private var connectionIndicator: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 10, height: 10)
                Text(connectionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                viewModel.checkConnection()
            } label: {
                Label("Check Connection", systemImage: "bolt.horizontal.circle")
            }
            .disabled(viewModel.connectionCheckStatus == .checking)

            if !viewModel.canTransmit {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("Sibling active")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var connectionColor: Color {
        switch viewModel.connectionCheckStatus {
        case .unknown: return .gray
        case .checking: return .yellow
        case .detected: return .green
        case .notDetected: return .red
        }
    }

    private var connectionLabel: String {
        switch viewModel.connectionCheckStatus {
        case .unknown: return "Not checked"
        case .checking: return "Checking…"
        case .detected: return "H9 Detected"
        case .notDetected: return "Not Detected"
        }
    }
}

/// Bridges `H9AudioUnit`'s parameter tree + engine state to SwiftUI bindings.
final class H9RemoteViewModel: ObservableObject {
    private let audioUnit: H9AudioUnit
    private let parameterTreeBuilder: H9ParameterTreeBuilder

    @Published var presetName: String = ""
    @Published var algorithmNumber: Int = 0
    @Published var moduleNumber: Int = 4
    @Published var performanceSwitch: Bool = false {
        didSet { if !isSyncingFromHardware { setParam(.performanceSwitch, performanceSwitch ? 1 : 0) } }
    }
    @Published var expression: Double = 0 {
        didSet { if !isSyncingFromHardware { setParam(.expression, expression) } }
    }
    @Published var tempo: Double = 120 {
        didSet { if !isSyncingFromHardware { setParam(.tempo, tempo) } }
    }
    @Published var tempoEnabled: Bool = false {
        didSet { if !isSyncingFromHardware { setParam(.tempoEnable, tempoEnabled ? 1 : 0) } }
    }
    @Published var outputGain: Double = 0 {
        didSet { if !isSyncingFromHardware { setParam(.outputGain, outputGain) } }
    }
    @Published var modfactorFastSlow: Bool = false {
        didSet { if !isSyncingFromHardware { setParam(.modfactorFastSlow, modfactorFastSlow ? 1 : 0) } }
    }
    @Published var canTransmit: Bool = true
    @Published var connectionCheckStatus: H9ConnectionCheckStatus = .unknown
    /// Which preset slot "Save Preset" targets next — chosen explicitly by
    /// the user at save time, independent of AU automation or hardware
    /// sync (matches how H9 Control's own "Save to Device" flow works).
    @Published var saveSlot: Int = 1

    @Published private var knobValues: [Double] = Array(repeating: 0, count: H9MIDICodec.knobCount)

    /// Suppresses the `didSet` → `setParam` → outgoing-MIDI feedback loop
    /// while `syncFromEngineState()` writes hardware-originated values into
    /// these same `@Published` properties.
    private var isSyncingFromHardware = false

    init(audioUnit: H9AudioUnit, parameterTreeBuilder: H9ParameterTreeBuilder) {
        self.audioUnit = audioUnit
        self.parameterTreeBuilder = parameterTreeBuilder
        audioUnit.onConnectionStatusChanged = { [weak self] status in
            self?.connectionCheckStatus = status
        }
        audioUnit.onHardwareStateChanged = { [weak self] in
            self?.syncFromEngineState()
        }
    }

    /// Pulls the AU's current values (already updated in `engineState` by
    /// `H9AudioUnit.handleIncomingMIDI`) into this view model's own
    /// `@Published` properties, so a hardware-originated change (sync
    /// reply, live knob turn on the pedal) actually appears in the
    /// plugin's UI — mirrors the standalone app's
    /// `H9StandaloneViewModel.syncPublishedValuesFromEngineState()`.
    private func syncFromEngineState() {
        isSyncingFromHardware = true
        let engineState = parameterTreeBuilder.engineState
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
        isSyncingFromHardware = false
    }

    func binding(forKnob index: Int) -> Binding<Double> {
        Binding(
            get: { self.knobValues[index - 1] },
            set: { newValue in
                self.knobValues[index - 1] = newValue
                self.setParam(H9Parameter.knobParameters[index - 1], newValue)
            }
        )
    }

    private func setParam(_ parameter: H9Parameter, _ value: Double) {
        parameterTreeBuilder.parameter(parameter)?.setValue(AUValue(value), originator: nil)
    }

    func setAlgorithm(index: Int, module: Int) {
        algorithmNumber = index
        moduleNumber = module
        setParam(.algorithmNumber, Double(index))
        setParam(.moduleNumber, Double(module))
    }

    func requestSyncFromHardware() {
        audioUnit.requestSyncFromHardware()
    }

    func pushCurrentStateToHardware() {
        audioUnit.pushCurrentStateToHardware()
    }

    func savePreset(toSlot slot: Int) {
        audioUnit.savePreset(toSlot: slot)
    }

    func checkConnection() {
        audioUnit.checkConnection()
    }
}

import SwiftUI
import H9RemoteCore

struct ContentView: View {
    @StateObject private var viewModel = H9StandaloneViewModel()
    @State private var showPluginInstructions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            midiPortPickers.h9SectionCard()
            controlSurface
            syncButtons.h9SectionCard()
            pluginInstructionsDisclosure
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 560)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Text("H9 Remote")
                .font(.largeTitle)
                .bold()
            Spacer()
            connectionIndicator
        }
    }

    private var currentLineage: H9PedalLineage {
        H9AlgorithmCatalog.algorithm(index: viewModel.algorithmNumber, module: viewModel.moduleNumber)?.lineage ?? .space
    }

    private var connectionIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(connectionColor)
                .frame(width: 12, height: 12)
            Text(connectionLabel)
                .font(.callout)
            Button {
                viewModel.checkConnection()
            } label: {
                Label("Check Connection", systemImage: "bolt.horizontal.circle")
            }
            .disabled(viewModel.connectionCheckStatus == .checking)
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

    private var midiPortPickers: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading) {
                Text("MIDI Output (to H9)").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: outputSelection) {
                    Text("None").tag(Optional<Int32>.none)
                    ForEach(viewModel.midi.destinations) { destination in
                        Text(destination.name).tag(Optional(destination.id))
                    }
                }
                .labelsHidden()
            }
            VStack(alignment: .leading) {
                Text("MIDI Input (from H9)").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: inputSelection) {
                    Text("None").tag(Optional<Int32>.none)
                    ForEach(viewModel.midi.sources) { source in
                        Text(source.name).tag(Optional(source.id))
                    }
                }
                .labelsHidden()
            }
            Button {
                viewModel.midi.refreshEndpoints()
            } label: {
                Label("Refresh Ports", systemImage: "arrow.clockwise")
            }
        }
    }

    private var outputSelection: Binding<Int32?> {
        Binding(
            get: { viewModel.midi.selectedDestinationID },
            set: { newValue in
                viewModel.midi.selectDestination(viewModel.midi.destinations.first { $0.id == newValue })
            }
        )
    }

    private var inputSelection: Binding<Int32?> {
        Binding(
            get: { viewModel.midi.selectedSourceID },
            set: { newValue in
                viewModel.midi.selectSource(viewModel.midi.sources.first { $0.id == newValue })
            }
        )
    }

    private var controlSurface: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Preset Name", text: $viewModel.presetName)
                    .textFieldStyle(.roundedBorder)
                algorithmPicker
                Spacer()
            }
            .h9SectionCard()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(1...10, id: \.self) { index in
                    H9KnobView(
                        value: Binding(
                            get: { viewModel.knobValues[index - 1] },
                            set: { viewModel.setKnob(index: index, value: $0) }
                        ),
                        label: knobLabels[index - 1],
                        accentColor: currentLineage.knobAccentColor,
                        format: knobFormats[index - 1]
                    )
                }
            }
            .h9SectionCard()

            HStack(spacing: 24) {
                Toggle("PSW", isOn: Binding(
                    get: { viewModel.performanceSwitch },
                    set: { viewModel.setPerformanceSwitch($0) }
                ))
                VStack(alignment: .leading) {
                    Text("Expression")
                    Slider(
                        value: Binding(
                            get: { viewModel.expression },
                            set: { viewModel.setExpression($0) }
                        ),
                        in: 0...1
                    )
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
        }
    }

    private var syncButtons: some View {
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
    }

    private var pluginInstructionsDisclosure: some View {
        DisclosureGroup("Using this as a plugin", isExpanded: $showPluginInstructions) {
            VStack(alignment: .leading, spacing: 8) {
                Text("This app also installs an AUv3 MIDI FX plugin. Add \"H9 Remote\" "
                     + "as a MIDI FX on a MIDI or External Instrument track in a host "
                     + "that supports MIDI FX plugins (Logic Pro, MainStage, REAPER "
                     + "7.55+). GarageBand does not support the MIDI FX slot.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("As an AUv3 App Extension, the plugin can only exchange MIDI with "
                     + "the host's own MIDI routing — you must route that track's MIDI "
                     + "input/output to the H9's physical MIDI ports yourself. This "
                     + "standalone app, by contrast, talks to the H9's MIDI ports "
                     + "directly.")
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }
}

#Preview {
    ContentView()
}

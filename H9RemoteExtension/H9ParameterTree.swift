import AudioToolbox
import H9RemoteCore

/// Builds the AUParameterTree exposing `H9Parameter`'s automatable
/// parameters, and keeps it in sync with an `H9EngineState`.
final class H9ParameterTreeBuilder {
    let engineState: H9EngineState
    let tree: AUParameterTree
    private var parametersByAddress: [UInt64: AUParameter] = [:]

    /// Called whenever the host changes a parameter's value (via automation
    /// or the AU's own UI), after engineState has been updated. The AUv3
    /// layer uses this to schedule outgoing MIDI.
    var onParameterChanged: ((H9Parameter, AUValue) -> Void)?

    init(engineState: H9EngineState) {
        self.engineState = engineState

        var parameters: [AUParameter] = []
        for p in H9Parameter.allCases {
            let param = AUParameterTree.createParameter(
                withIdentifier: p.identifier,
                name: p.displayName,
                address: p.address,
                min: p.minValue,
                max: p.maxValue,
                unit: p.isBoolean ? .boolean : (p == .tempo ? .BPM : .generic),
                unitName: nil,
                flags: [.flag_IsReadable, .flag_IsWritable],
                valueStrings: nil,
                dependentParameters: nil
            )
            param.value = p.defaultValue
            parameters.append(param)
            parametersByAddress[p.address] = param
        }

        tree = AUParameterTree.createTree(withChildren: parameters)

        tree.implementorValueObserver = { [weak self] parameter, value in
            self?.handleValueChanged(parameter: parameter, value: value)
        }
        tree.implementorValueProvider = { [weak self] parameter in
            guard let self, let p = H9Parameter(rawValue: Int(parameter.address)) else { return 0 }
            return AUValue(self.engineState.value(for: p))
        }
    }

    private func handleValueChanged(parameter: AUParameter, value: AUValue) {
        guard let p = H9Parameter(rawValue: Int(parameter.address)) else { return }
        engineState.setValue(Double(value), for: p)
        onParameterChanged?(p, value)
    }

    /// Pushes engineState's current values into the parameter tree (used
    /// after applying an incoming SysEx dump or CC, so the host UI reflects
    /// hardware-originated changes).
    func syncTreeFromEngineState() {
        for p in H9Parameter.allCases {
            parametersByAddress[p.address]?.setValue(
                AUValue(engineState.value(for: p)),
                originator: nil
            )
        }
    }

    func parameter(_ p: H9Parameter) -> AUParameter? {
        parametersByAddress[p.address]
    }
}

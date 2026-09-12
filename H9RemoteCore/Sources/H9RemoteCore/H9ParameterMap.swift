import Foundation

/// Canonical list of AU-automatable parameters exposed by the H9 Remote AU,
/// mirroring a subset of the original device's ~40 `pattrstorage` variables.
/// Per-knob expression min/max and PSW-map (30 variables) are deliberately
/// excluded from v1 — see the project plan's "Explicitly deferred" section.
public enum H9Parameter: Int, CaseIterable {
    case knob1, knob2, knob3, knob4, knob5
    case knob6, knob7, knob8, knob9, knob10
    case performanceSwitch
    case expression
    case tempo
    case tempoEnable
    case outputGain
    case modfactorFastSlow
    case algorithmNumber
    case moduleNumber

    public var address: UInt64 { UInt64(rawValue) }

    public var identifier: String {
        switch self {
        case .knob1: return "knob1"
        case .knob2: return "knob2"
        case .knob3: return "knob3"
        case .knob4: return "knob4"
        case .knob5: return "knob5"
        case .knob6: return "knob6"
        case .knob7: return "knob7"
        case .knob8: return "knob8"
        case .knob9: return "knob9"
        case .knob10: return "knob10"
        case .performanceSwitch: return "psw"
        case .expression: return "expression"
        case .tempo: return "tempo"
        case .tempoEnable: return "tempoEnable"
        case .outputGain: return "outputGain"
        case .modfactorFastSlow: return "modfactorFastSlow"
        case .algorithmNumber: return "algorithmNumber"
        case .moduleNumber: return "moduleNumber"
        }
    }

    public var displayName: String {
        switch self {
        case .knob1, .knob2, .knob3, .knob4, .knob5,
             .knob6, .knob7, .knob8, .knob9, .knob10:
            return "Knob \(rawValue + 1)"
        case .performanceSwitch: return "PSW"
        case .expression: return "Expression"
        case .tempo: return "Tempo"
        case .tempoEnable: return "Tempo Enabled"
        case .outputGain: return "Output Gain"
        case .modfactorFastSlow: return "Modfactor Fast/Slow"
        case .algorithmNumber: return "Algorithm"
        case .moduleNumber: return "Module"
        }
    }

    public var minValue: Float {
        switch self {
        case .tempo: return 20
        case .algorithmNumber: return 0
        case .moduleNumber: return 1
        default: return 0
        }
    }

    public var maxValue: Float {
        switch self {
        case .tempo: return 300
        case .outputGain: return 12
        case .algorithmNumber: return 127
        case .moduleNumber: return 5
        case .performanceSwitch, .tempoEnable, .modfactorFastSlow: return 1
        default: return 1
        }
    }

    public var defaultValue: Float {
        switch self {
        case .tempo: return 120
        case .moduleNumber: return 4
        default: return 0
        }
    }

    public var isBoolean: Bool {
        switch self {
        case .performanceSwitch, .tempoEnable, .modfactorFastSlow: return true
        default: return false
        }
    }

    public static var knobParameters: [H9Parameter] {
        [.knob1, .knob2, .knob3, .knob4, .knob5, .knob6, .knob7, .knob8, .knob9, .knob10]
    }

    /// 1-based knob index (1...10) if this is a knob parameter, else nil.
    public var knobIndex: Int? {
        H9Parameter.knobParameters.firstIndex(of: self).map { $0 + 1 }
    }
}

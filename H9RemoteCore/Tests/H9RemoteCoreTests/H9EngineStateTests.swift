import XCTest
@testable import H9RemoteCore

final class H9EngineStateTests: XCTestCase {
    func testApplyingIncomingCCPairAssemblesKnobValue() {
        let state = H9EngineState()
        let pair = H9MIDICodec.encodeKnob(knobIndex: 5, normalizedValue: 0.42)
        state.applyIncomingCC(channel: 1, ccNumber: pair.coarseCC, value: pair.coarseValue)
        state.applyIncomingCC(channel: 1, ccNumber: pair.fineCC, value: pair.fineValue)
        XCTAssertEqual(state.knobValues[4], 0.42, accuracy: 1.0 / 16383.0 + 1e-6)
    }

    func testIncomingCCIgnoredOnWrongChannel() {
        let state = H9EngineState()
        state.midiRxChannel = 2
        let applied = state.applyIncomingCC(channel: 1, ccNumber: state.pswCCNumber, value: 127)
        XCTAssertFalse(applied)
        XCTAssertFalse(state.performanceSwitch)
    }

    func testPerformanceSwitchThreshold() {
        let state = H9EngineState()
        state.applyIncomingCC(channel: 1, ccNumber: state.pswCCNumber, value: 63)
        XCTAssertFalse(state.performanceSwitch)
        state.applyIncomingCC(channel: 1, ccNumber: state.pswCCNumber, value: 64)
        XCTAssertTrue(state.performanceSwitch)
    }

    func testMakeProgramDumpAndApplyRoundTrips() throws {
        let state = H9EngineState()
        state.knobValues = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
        state.presetName = "Test Preset"
        state.presetNumber = 12
        state.algorithmNumber = 5
        state.moduleNumber = 2

        let bytes = state.makePushSysEx()
        guard case .programDumpPayload(let payload) = H9SysExCodec.parse(bytes, expectedSysexID: state.sysexID) else {
            return XCTFail("expected programDumpPayload")
        }
        let text = String(decoding: payload, as: UTF8.self)
        let dump = try H9ProgramDump.parse(text: text)

        let restored = H9EngineState()
        restored.apply(dump)
        XCTAssertEqual(restored.presetName, "Test Preset")
        XCTAssertEqual(restored.presetNumber, 12)
        XCTAssertEqual(restored.algorithmNumber, 5)
        XCTAssertEqual(restored.moduleNumber, 2)
        for i in 0..<10 {
            XCTAssertEqual(restored.knobValues[i], state.knobValues[i], accuracy: 1e-3)
        }
    }

    func testMakePullRequestSysExUsesConfiguredSysexID() {
        let state = H9EngineState()
        state.sysexID = 7
        let bytes = state.makePullRequestSysEx()
        XCTAssertEqual(bytes, H9SysExCodec.getCurrentPresetRequest(sysexID: 7))
    }
}

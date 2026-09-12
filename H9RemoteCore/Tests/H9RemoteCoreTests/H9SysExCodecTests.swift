import XCTest
@testable import H9RemoteCore

final class H9SysExCodecTests: XCTestCase {
    func testGetCurrentPresetRequestBytes() {
        let bytes = H9SysExCodec.getCurrentPresetRequest(sysexID: 1)
        XCTAssertEqual(bytes, [0xF0, 0x1C, 0x70, 0x01, 78, 0xF7])
    }

    func testDumpAllPresetsRequestBytes() {
        let bytes = H9SysExCodec.dumpAllPresetsRequest(sysexID: 1)
        XCTAssertEqual(bytes, [0xF0, 0x1C, 0x70, 0x01, 72, 0xF7])
    }

    func testParseRecognizesGetCurrentPresetRequest() {
        let bytes = H9SysExCodec.getCurrentPresetRequest(sysexID: 3)
        XCTAssertEqual(H9SysExCodec.parse(bytes, expectedSysexID: 3), .getCurrentPresetRequest)
    }

    func testParseRejectsWrongSysexID() {
        let bytes = H9SysExCodec.getCurrentPresetRequest(sysexID: 3)
        XCTAssertEqual(H9SysExCodec.parse(bytes, expectedSysexID: 1), .unrecognized)
    }

    func testParseRejectsForeignManufacturer() {
        let bytes: [UInt8] = [0xF0, 0x00, 0x70, 0x01, 78, 0xF7]
        XCTAssertEqual(H9SysExCodec.parse(bytes, expectedSysexID: 1), .unrecognized)
    }

    func testWrapAndParseProgramDumpRoundTrips() throws {
        let text = H9ProgramDumpFixtures.hall
        let bytes = Array(text.utf8)
        let wrapped = H9SysExCodec.wrapProgramDump(bytes, sysexID: 1)
        XCTAssertEqual(wrapped.first, 0xF0)
        XCTAssertEqual(wrapped.last, 0xF7)

        guard case .programDumpPayload(let payload) = H9SysExCodec.parse(wrapped, expectedSysexID: 1) else {
            return XCTFail("expected programDumpPayload")
        }
        let roundTripText = String(decoding: payload, as: UTF8.self)
        let dump = try H9ProgramDump.parse(text: roundTripText)
        XCTAssertEqual(dump.presetName, "Hall")
    }
}

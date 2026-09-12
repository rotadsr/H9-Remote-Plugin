import XCTest
@testable import H9RemoteCore

final class H9DeviceDetectionTests: XCTestCase {
    private func wrapped(_ text: String, sysexID: UInt8 = 1) -> [UInt8] {
        H9SysExCodec.wrapProgramDump(Array(text.utf8), sysexID: sysexID)
    }

    func testValidGoldenFixturesAreDetected() {
        XCTAssertTrue(H9DeviceDetection.isDetectionResponse(wrapped(H9ProgramDumpFixtures.hall), sysexID: 1))
        XCTAssertTrue(H9DeviceDetection.isDetectionResponse(wrapped(H9ProgramDumpFixtures.iWalkAlone), sysexID: 1))
        XCTAssertTrue(H9DeviceDetection.isDetectionResponse(wrapped(H9ProgramDumpFixtures.hrmdlo), sysexID: 1))
    }

    func testCorruptedChecksumIsNotDetected() {
        let corrupted = H9ProgramDumpFixtures.hall.replacingOccurrences(of: "C_032c", with: "C_ffff")
        XCTAssertFalse(H9DeviceDetection.isDetectionResponse(wrapped(corrupted), sysexID: 1))
    }

    func testWrongSysexIDIsNotDetected() {
        let bytes = wrapped(H9ProgramDumpFixtures.hall, sysexID: 3)
        XCTAssertFalse(H9DeviceDetection.isDetectionResponse(bytes, sysexID: 1))
    }

    func testRequestEchoIsNotDetected() {
        // A device that just echoes the request back (or MIDI loopback) should
        // not be mistaken for a real reply.
        let bytes = H9SysExCodec.getCurrentPresetRequest(sysexID: 1)
        XCTAssertFalse(H9DeviceDetection.isDetectionResponse(bytes, sysexID: 1))
    }

    func testGarbageBytesAreNotDetected() {
        XCTAssertFalse(H9DeviceDetection.isDetectionResponse([0xF0, 0x1C, 0x70, 0x01, 0x01, 0x02, 0xF7], sysexID: 1))
        XCTAssertFalse(H9DeviceDetection.isDetectionResponse([], sysexID: 1))
    }

    /// A real reply captured from a physical H9 Pedal over USB-MIDI (its
    /// current preset, "DUALVERB"). Its expr-map/PSW line has 27 fields, not
    /// the 30 fixed by the 3 static fixtures above — this is the case that
    /// originally made "Check Connection" always report Not Detected against
    /// real hardware even though the pedal was replying correctly.
    func testRealHardwareCaptureIsDetected() {
        let payload = Array(
            ("[86] 4 5 4\r\n" +
             " 4 51d7 5540 5688 71df 7501 5465 3d91 4700 2e08 4ebe 3ac2\r\n" +
             " 0 0 0 0 3b40 76a0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 204c 0\r\n" +
             " 0 2ee0 1 0 9 8 0 0\r\n" +
             " 16 18 69.6987 35.62 83 32 13 22.21 9 44.94 65000 65000\r\n" +
             "C_7344\r\n" +
             "DUALVERB\r\n" +
             "\u{0}").utf8
        )
        let bytes = H9SysExCodec.wrapProgramDump(payload, sysexID: 1)
        XCTAssertTrue(H9DeviceDetection.isDetectionResponse(bytes, sysexID: 1))
    }
}

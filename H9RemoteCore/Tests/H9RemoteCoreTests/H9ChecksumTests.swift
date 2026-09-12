import XCTest
@testable import H9RemoteCore

final class H9ChecksumTests: XCTestCase {
    func testHallChecksum() throws {
        let dump = try H9ProgramDump.parse(text: H9ProgramDumpFixtures.hall)
        XCTAssertEqual(dump.presetName, "Hall")
        XCTAssertEqual(dump.presetNumber, 1)
        XCTAssertEqual(dump.algorithmNumber, 0)
        XCTAssertEqual(dump.moduleNumber, 4)
    }

    func testIWalkAloneChecksum() throws {
        let dump = try H9ProgramDump.parse(text: H9ProgramDumpFixtures.iWalkAlone)
        XCTAssertEqual(dump.presetName, "I WALK ALONE")
        XCTAssertEqual(dump.presetNumber, 14)
        XCTAssertEqual(dump.algorithmNumber, 6)
        XCTAssertEqual(dump.moduleNumber, 2)
    }

    func testHRMDLOChecksumWithTrailingNUL() throws {
        let dump = try H9ProgramDump.parse(text: H9ProgramDumpFixtures.hrmdlo)
        XCTAssertEqual(dump.presetName, "HRMDLO")
        XCTAssertEqual(dump.presetNumber, 82)
        XCTAssertEqual(dump.algorithmNumber, 8)
        XCTAssertEqual(dump.moduleNumber, 5)
    }

    func testChecksumMismatchIsDetected() {
        let corrupted = H9ProgramDumpFixtures.hall.replacingOccurrences(of: "C_032c", with: "C_ffff")
        XCTAssertThrowsError(try H9ProgramDump.parse(text: corrupted)) { error in
            guard case H9ProgramDumpError.checksumMismatch(let expected, let computed) = error else {
                return XCTFail("expected checksumMismatch, got \(error)")
            }
            XCTAssertEqual(expected, "ffff")
            XCTAssertEqual(computed, "032c")
        }
    }

    func testChecksumParseRejectsMalformedField() {
        XCTAssertNil(H9Checksum.parse("nope"))
        XCTAssertNil(H9Checksum.parse("C_zzzz"))
        XCTAssertNil(H9Checksum.parse("C_12"))
    }

    func testChecksumFormatMasksTo16Bits() {
        XCTAssertEqual(H9Checksum.format(0x1_0000 + 0x032c), "032c")
    }
}

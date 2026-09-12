import XCTest
@testable import H9RemoteCore

final class H9ProgramDumpTests: XCTestCase {
    func testParseKnobOrderingMatchesCounterClockwiseComment() throws {
        // The patch explicitly documents knob field order as
        // "7 8 9 10 6 5 4 3 2 1 expr" (counter-clockwise from bottom-left).
        // Verify our line1Hex indexing produces knobValues[0] == knob1's own
        // hex field (the 11th value in that documented order).
        let dump = try H9ProgramDump.parse(text: H9ProgramDumpFixtures.hall)
        XCTAssertEqual(dump.knobValues.count, 10)
        // knob1's raw hex field in the Hall fixture line1 is "3eb6"
        let expectedKnob1 = Double(0x3eb6) / 32736.0
        XCTAssertEqual(dump.knobValues[0], expectedKnob1, accuracy: 1e-9)
        // knob7's raw hex field in the Hall fixture line1 is "2500" (2nd field)
        let expectedKnob7 = Double(0x2500) / 32736.0
        XCTAssertEqual(dump.knobValues[6], expectedKnob7, accuracy: 1e-9)
    }

    func testPerformanceSwitchMapParsedAsBooleans() throws {
        let dump = try H9ProgramDump.parse(text: H9ProgramDumpFixtures.hall)
        XCTAssertEqual(dump.knobPerformanceSwitchMap.count, 10)
        XCTAssertTrue(dump.knobPerformanceSwitchMap.allSatisfy { $0 == false || $0 == true })
    }

    func testSerializeThenParseRoundTripsChecksum() throws {
        let original = try H9ProgramDump.parse(text: H9ProgramDumpFixtures.hall)
        let serialized = original.serializeText()
        let reparsed = try H9ProgramDump.parse(text: serialized)
        XCTAssertEqual(reparsed.presetName, original.presetName)
        XCTAssertEqual(reparsed.presetNumber, original.presetNumber)
        XCTAssertEqual(reparsed.algorithmNumber, original.algorithmNumber)
        XCTAssertEqual(reparsed.moduleNumber, original.moduleNumber)
        for i in 0..<10 {
            XCTAssertEqual(reparsed.knobValues[i], original.knobValues[i], accuracy: 1e-4)
        }
    }

    func testMalformedTextThrows() {
        XCTAssertThrowsError(try H9ProgramDump.parse(text: "not a program dump"))
    }
}

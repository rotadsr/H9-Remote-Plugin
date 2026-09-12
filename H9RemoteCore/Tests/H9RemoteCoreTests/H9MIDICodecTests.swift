import XCTest
@testable import H9RemoteCore

final class H9MIDICodecTests: XCTestCase {
    func testEncodeKnobUsesConfiguredOffset() {
        let pair = H9MIDICodec.encodeKnob(knobIndex: 1, normalizedValue: 0, knobCCOffset: 22)
        XCTAssertEqual(pair.coarseCC, 22)
        XCTAssertEqual(pair.fineCC, 22 + 32)

        let pair10 = H9MIDICodec.encodeKnob(knobIndex: 10, normalizedValue: 0, knobCCOffset: 22)
        XCTAssertEqual(pair10.coarseCC, 31)
        XCTAssertEqual(pair10.fineCC, 31 + 32)
    }

    func testKnobRoundTripAtEdgeValues() {
        for value in [0.0, 1.0, 0.5, 0.25, 0.999] {
            let pair = H9MIDICodec.encodeKnob(knobIndex: 3, normalizedValue: value)
            let decoded = H9MIDICodec.decodeKnob(coarseValue: pair.coarseValue, fineValue: pair.fineValue)
            XCTAssertEqual(decoded, value, accuracy: 1.0 / 16383.0 + 1e-9)
        }
    }

    func testKnobValuesClampToUnitRange() {
        let low = H9MIDICodec.encodeKnob(knobIndex: 1, normalizedValue: -1)
        XCTAssertEqual(low.coarseValue, 0)
        XCTAssertEqual(low.fineValue, 0)

        let high = H9MIDICodec.encodeKnob(knobIndex: 1, normalizedValue: 2)
        let decodedHigh = H9MIDICodec.decodeKnob(coarseValue: high.coarseValue, fineValue: high.fineValue)
        XCTAssertEqual(decodedHigh, 1.0, accuracy: 1e-6)
    }

    func testCCRoleClassification() {
        XCTAssertEqual(H9MIDICodec.role(ccNumber: 22), .knobCoarse(index: 1))
        XCTAssertEqual(H9MIDICodec.role(ccNumber: 31), .knobCoarse(index: 10))
        XCTAssertEqual(H9MIDICodec.role(ccNumber: 54), .knobFine(index: 1))
        XCTAssertEqual(H9MIDICodec.role(ccNumber: 63), .knobFine(index: 10))
        XCTAssertEqual(H9MIDICodec.role(ccNumber: 71), .performanceSwitch)
        XCTAssertEqual(H9MIDICodec.role(ccNumber: 11), .expression)
        XCTAssertEqual(H9MIDICodec.role(ccNumber: 100), .other)
    }

    func testSingleCCRoundTrip() {
        for raw: UInt8 in [0, 64, 127] {
            let normalized = H9MIDICodec.decodeSingleCC(raw)
            let reencoded = H9MIDICodec.encodeSingleCC(normalizedValue: normalized)
            XCTAssertEqual(reencoded, raw)
        }
    }
}

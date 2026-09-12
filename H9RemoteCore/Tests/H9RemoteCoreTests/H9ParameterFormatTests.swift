import XCTest
@testable import H9RemoteCore

final class H9ParameterFormatTests: XCTestCase {
    func testPercentFormat() {
        let format = H9ParameterFormat.percent
        XCTAssertEqual(format.format(0), "0%")
        XCTAssertEqual(format.format(1), "100%")
        XCTAssertEqual(format.format(0.5), "50%")
        XCTAssertEqual(format.format(0.734), "73%")
    }

    func testLinearFormatDelayMilliseconds() {
        // Digital Delay's "Delay A"/"Delay B": explicitly documented 0-3000ms range.
        let format = H9ParameterFormat.linear(min: 0, max: 3000, unit: "ms", decimals: 0)
        XCTAssertEqual(format.format(0), "0 ms")
        XCTAssertEqual(format.format(1), "3000 ms")
        XCTAssertEqual(format.format(0.5), "1500 ms")
    }

    func testLinearFormatWithDecimals() {
        // Delay-algorithm mod rate: explicitly documented 0-5Hz range.
        let format = H9ParameterFormat.linear(min: 0, max: 5, unit: "Hz", decimals: 1)
        XCTAssertEqual(format.format(0), "0.0 Hz")
        XCTAssertEqual(format.format(1), "5.0 Hz")
        XCTAssertEqual(format.format(0.5), "2.5 Hz")
    }

    func testBipolarFormatNoUnit() {
        let format = H9ParameterFormat.bipolar(min: -100, max: 100, unit: "", decimals: 0)
        XCTAssertEqual(format.format(0), "-100")
        XCTAssertEqual(format.format(1), "100")
        XCTAssertEqual(format.format(0.5), "0")
    }

    func testDiscreteFormatSelectsNearestOption() {
        let format = H9ParameterFormat.discrete(options: ["Lowpass", "Bandpass", "Highpass"])
        XCTAssertEqual(format.format(0), "Lowpass")
        XCTAssertEqual(format.format(1), "Highpass")
        XCTAssertEqual(format.format(0.5), "Bandpass")
    }

    func testDiscreteFormatWithEmptyOptionsFallsBackToPercent() {
        let format = H9ParameterFormat.discrete(options: [])
        XCTAssertEqual(format.format(0.5), "50%")
    }

    func testFormatClampsOutOfRangeInput() {
        let format = H9ParameterFormat.linear(min: 0, max: 100, unit: "", decimals: 0)
        XCTAssertEqual(format.format(-0.5), "0")
        XCTAssertEqual(format.format(1.5), "100")
    }

    func testAlgorithmDefaultsToPercentForAllTenKnobsWhenUnspecified() {
        let algorithm = H9Algorithm(index: 0, module: 4, name: "Test", knobLabels: Array(repeating: "X", count: 10), buttonLabel: "Y")
        XCTAssertEqual(algorithm.knobFormats, Array(repeating: .percent, count: 10))
    }

    func testCatalogKnobFormatsFallsBackToPercentForUnknownAlgorithm() {
        XCTAssertEqual(H9AlgorithmCatalog.knobFormats(index: 99, module: 99), Array(repeating: .percent, count: 10))
    }
}

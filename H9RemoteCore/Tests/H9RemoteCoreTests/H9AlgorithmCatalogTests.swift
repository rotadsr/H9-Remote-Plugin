import XCTest
@testable import H9RemoteCore

final class H9AlgorithmCatalogTests: XCTestCase {
    func testCatalogHasExactly52Entries() {
        XCTAssertEqual(H9AlgorithmCatalog.all.count, 52)
    }

    func testNoDuplicateIndexModulePairs() {
        let keys = H9AlgorithmCatalog.all.map { "\($0.module)-\($0.index)" }
        XCTAssertEqual(keys.count, Set(keys).count)
    }

    func testKnownAlgorithmsResolveToCorrectNames() {
        XCTAssertEqual(H9AlgorithmCatalog.algorithm(index: 0, module: 4)?.name, "Hall")
        XCTAssertEqual(H9AlgorithmCatalog.algorithm(index: 8, module: 5)?.name, "Harmadillo")
        XCTAssertEqual(H9AlgorithmCatalog.algorithm(index: 4, module: 4)?.name, "DualVerb")
    }

    func testEveryAlgorithmHasExactlyTenKnobLabelSlots() {
        for algorithm in H9AlgorithmCatalog.all {
            XCTAssertEqual(algorithm.knobLabels.count, 10, "\(algorithm.name) should have 10 knob label slots")
        }
    }

    func testUnknownAlgorithmFallsBackToGenericLabels() {
        XCTAssertEqual(
            H9AlgorithmCatalog.knobLabels(index: 99, module: 99),
            (1...10).map { "Knob \($0)" }
        )
    }

    func testLineageMatchesModule() {
        XCTAssertEqual(H9AlgorithmCatalog.algorithm(index: 0, module: 1)?.lineage, .timeFactor)
        XCTAssertEqual(H9AlgorithmCatalog.algorithm(index: 0, module: 2)?.lineage, .modFactor)
        XCTAssertEqual(H9AlgorithmCatalog.algorithm(index: 0, module: 3)?.lineage, .pitchFactor)
        XCTAssertEqual(H9AlgorithmCatalog.algorithm(index: 0, module: 4)?.lineage, .space)
        XCTAssertEqual(H9AlgorithmCatalog.algorithm(index: 0, module: 5)?.lineage, .h9New)
    }

    func testEveryLineageHasEntries() {
        for lineage in H9PedalLineage.allCases {
            XCTAssertFalse(
                H9AlgorithmCatalog.all.filter { $0.lineage == lineage }.isEmpty,
                "\(lineage) should have at least one algorithm"
            )
        }
    }
}

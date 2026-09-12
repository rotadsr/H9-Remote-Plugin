import XCTest
@testable import H9RemoteCore

final class H9ConnectionGuardTests: XCTestCase {
    func testDefaultsToLocallyEnabled() {
        let guardState = H9ConnectionGuard()
        XCTAssertTrue(guardState.canTransmit)
    }

    func testDisablingLocallyUpdatesStatus() {
        let guardState = H9ConnectionGuard()
        guardState.setLocalEnable(false)
        XCTAssertFalse(guardState.canTransmit)
        XCTAssertEqual(guardState.status, .disabledBySibling)
    }

    func testSiblingEnableDisablesThisInstance() {
        let guardState = H9ConnectionGuard()
        guardState.receiveExternalEnable(fromSiblingEnabled: true)
        XCTAssertFalse(guardState.canTransmit)
        XCTAssertEqual(guardState.status, .disabledBySibling)
    }

    func testSiblingDisableDoesNotReEnableAutomatically() {
        let guardState = H9ConnectionGuard()
        guardState.receiveExternalEnable(fromSiblingEnabled: true)
        guardState.receiveExternalEnable(fromSiblingEnabled: false)
        XCTAssertFalse(guardState.canTransmit)
    }

    func testReEnablingLocallyRestoresTransmit() {
        let guardState = H9ConnectionGuard()
        guardState.receiveExternalEnable(fromSiblingEnabled: true)
        guardState.setLocalEnable(true)
        XCTAssertTrue(guardState.canTransmit)
        XCTAssertEqual(guardState.status, .enabledLocally)
    }
}

import XCTest
import ServiceManagement
@testable import CopyCatKit

@MainActor
final class LoginItemTests: XCTestCase {
    func testRegistrationReflectsSystemApprovalAndRefresh() {
        var status = SMAppService.Status.notRegistered
        let item = LoginItem(readStatus: { status }, register: { status = .requiresApproval }, unregister: { status = .notRegistered })
        XCTAssertFalse(item.isOn)
        item.setEnabled(true)
        XCTAssertEqual(item.status, .requiresApproval)
        XCTAssertTrue(item.isOn)
        status = .enabled
        item.refresh()
        XCTAssertEqual(item.status, .enabled)
        status = .notRegistered // user disables in System Settings
        item.refresh()
        XCTAssertFalse(item.isOn)
        item.setEnabled(true)
        item.setEnabled(false)
        XCTAssertFalse(item.isOn)
    }

    func testFailureDoesNotPretendRegistrationSucceeded() {
        let item = LoginItem(readStatus: { .notRegistered }, register: { throw NSError(domain: "test", code: 1) })
        item.setEnabled(true)
        XCTAssertFalse(item.isOn)
        XCTAssertNotNil(item.error)
    }

    func testFailedUnregisterKeepsActualState() {
        let item = LoginItem(readStatus: { .enabled }, unregister: { throw NSError(domain: "test", code: 2) })
        item.setEnabled(false)
        XCTAssertTrue(item.isOn)
        XCTAssertNotNil(item.error)
    }
}

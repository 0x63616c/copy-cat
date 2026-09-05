import XCTest
@testable import CopyCatKit

@MainActor
final class ScreenshotPreferencesTests: XCTestCase {
    func testAbsentThumbnailPreferenceKeepsMacOSDefaultVisible() {
        XCTAssertFalse(SystemScreencapturePreferences.hidesFloatingThumbnail(showThumbnail: nil))
    }

    func testExplicitThumbnailPreferenceIsInvertedForHideToggle() {
        XCTAssertTrue(SystemScreencapturePreferences.hidesFloatingThumbnail(showThumbnail: false))
        XCTAssertFalse(SystemScreencapturePreferences.hidesFloatingThumbnail(showThumbnail: true))
    }
}

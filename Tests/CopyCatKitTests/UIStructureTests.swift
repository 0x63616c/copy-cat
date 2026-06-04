import XCTest
import SwiftUI
import ViewInspector
@testable import CopyCatKit

@MainActor
final class UIStructureTests: XCTestCase {
    func testEmptyStateShowsPrompt() throws {
        let view = EmptyStateView()
        XCTAssertNoThrow(try view.inspect().find(text: "No screenshots yet."))
        XCTAssertNoThrow(try view.inspect().find(text: "Press ⌘⇧3 or ⌘⇧4 to take one."))
    }

    func testNoAccessOffersThreeRecoveryButtons() throws {
        let view = NoAccessView(
            onChooseFolder: {},
            onUseEscapeHatch: {},
            onOpenSettings: {})
        XCTAssertNoThrow(try view.inspect().find(button: "Choose folder…"))
        XCTAssertNoThrow(try view.inspect().find(button: "Use a folder that needs no permission"))
        XCTAssertNoThrow(try view.inspect().find(button: "Open System Settings"))
    }

    func testNotSavingBannerEnableButtonFires() throws {
        var enabled = false
        let view = NotSavingBanner(onEnable: { enabled = true }, onDisableThumbnail: {})
        try view.inspect().find(button: "Enable").tap()
        XCTAssertTrue(enabled)
    }
}

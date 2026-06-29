import XCTest
import SwiftUI
import ViewInspector
import CopyCatCore
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

    func testShortcutRecorderRendersHyperGlyphs() throws {
        let view = ShortcutRecorderView(
            title: "Open CopyCat",
            systemImage: "menubar.arrow.up.rectangle",
            shortcut: .constant(.hyper(7)))  // ⌃⌥⇧⌘X
        XCTAssertNoThrow(try view.inspect().find(text: "Open CopyCat"))
        XCTAssertNoThrow(try view.inspect().find(text: "⌃⌥⇧⌘X"))
    }

    func testShortcutRecorderRendersCustomCombo() throws {
        let view = ShortcutRecorderView(
            title: "Copy last screenshot",
            systemImage: "doc.on.clipboard",
            shortcut: .constant(HotKey(keyCode: 8, command: true, shift: true)))  // ⇧⌘C
        XCTAssertNoThrow(try view.inspect().find(text: "⇧⌘C"))
    }
}

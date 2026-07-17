import XCTest
@testable import CopyCatCore

final class KeyboardShortcutTests: XCTestCase {
    func testHyperHasAllFourModifiers() {
        let s = HotKey.hyper(7)
        XCTAssertTrue(s.command && s.control && s.option && s.shift)
        XCTAssertEqual(s.keyCode, 7)
    }

    func testHyperDisplayString() {
        // The Hyper combo collapses to the single ✦ glyph.
        XCTAssertEqual(HotKey.hyper(7).displayString, "✦X")
        XCTAssertEqual(HotKey.hyper(8).displayString, "✦C")
    }

    func testModifierOrderInDisplay() {
        // Control, Option, Shift order regardless of how set (not the Hyper
        // combo — that renders as ✦).
        let s = HotKey(keyCode: 0, control: true, option: true, shift: true)
        XCTAssertEqual(s.displayString, "⌃⌥⇧A")
    }

    func testHasModifier() {
        XCTAssertFalse(HotKey(keyCode: 7).hasModifier)
        XCTAssertTrue(HotKey(keyCode: 7, command: true).hasModifier)
    }

    func testUnknownKeyFallback() {
        XCTAssertEqual(HotKey.keyName(for: 200), "key 200")
    }

    func testRoundTripCodable() throws {
        let s = HotKey.hyper(8)
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(HotKey.self, from: data)
        XCTAssertEqual(s, back)
    }

    // MARK: AppSettings backward-compat

    func testDefaultsCarryHyperShortcuts() {
        XCTAssertEqual(AppSettings.defaults.openMenuShortcut, .hyper(7))
        XCTAssertEqual(AppSettings.defaults.copyLastShortcut, .hyper(8))
    }

    func testDecodeOldConfigWithoutShortcutsKeepsOtherFields() throws {
        // A config.json written before shortcuts existed.
        let json = """
        { "copyOnScreenshot": false, "saveLocationPath": "/tmp/shots" }
        """.data(using: .utf8)!
        let s = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertFalse(s.copyOnScreenshot)
        XCTAssertEqual(s.saveLocationPath, "/tmp/shots")
        // Missing shortcut keys fall back to Hyper defaults.
        XCTAssertEqual(s.openMenuShortcut, .hyper(7))
        XCTAssertEqual(s.copyLastShortcut, .hyper(8))
    }

    func testDecodeConfigWithCustomShortcuts() throws {
        let s = AppSettings(
            copyOnScreenshot: true,
            saveLocationPath: nil,
            openMenuShortcut: HotKey(keyCode: 17, command: true), // ⌘T
            copyLastShortcut: .hyper(8))
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(back.openMenuShortcut, HotKey(keyCode: 17, command: true))
        XCTAssertEqual(back.openMenuShortcut.displayString, "⌘T")
    }
}

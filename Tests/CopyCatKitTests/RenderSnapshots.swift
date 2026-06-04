import XCTest
import SwiftUI
import CopyCatCore
@testable import CopyCatKit

/// Renders the SwiftUI surfaces to PNGs under docs/screenshots/ so the UI can be
/// reviewed as pixels (no Screen Recording permission needed). Not a pass/fail
/// assertion of appearance — it fails only if rendering throws or produces no
/// image.
@MainActor
final class RenderSnapshots: XCTestCase {
    private func outputDir() -> URL {
        // <root>/Tests/CopyCatKitTests/RenderSnapshots.swift -> <root>
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dir = root.appendingPathComponent("docs/screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func render(_ view: some View, to name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage, "renderer produced no image for \(name)")
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let rep = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try png.write(to: outputDir().appendingPathComponent(name))
    }

    func testRenderEmptyState() throws {
        let controller = AppController(
            store: makeTempStore(), clipboard: FakeClipboard(),
            prefs: FakePrefs(), access: FakeAccess())
        try render(
            PopoverRootView().environmentObject(controller).frame(width: 720, height: 460),
            to: "popover-empty.png")
    }

    func testRenderNoAccessState() throws {
        let access = FakeAccess()
        access.readable = false
        let controller = AppController(
            store: makeTempStore(), clipboard: FakeClipboard(),
            prefs: FakePrefs(), access: access)
        controller.refreshStatus()
        try render(
            PopoverRootView().environmentObject(controller).frame(width: 720, height: 460),
            to: "popover-no-access.png")
    }

    func testRenderNotSavingBanner() throws {
        try render(
            NotSavingBanner(onEnable: {}, onDisableThumbnail: {})
                .frame(width: 700).padding().background(Color(NSColor.windowBackgroundColor)),
            to: "banner-not-saving.png")
    }
}

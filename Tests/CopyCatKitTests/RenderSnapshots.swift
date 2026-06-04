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
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dir = root.appendingPathComponent("docs/screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func tmpDir() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("copy-cat-samples", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Draws a labelled solid-color PNG and returns a Screenshot pointing at it.
    private func sample(_ name: String, _ size: CGSize, _ color: NSColor) -> Screenshot {
        let img = NSImage(size: size)
        img.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        (name as NSString).draw(
            at: NSPoint(x: 10, y: 10),
            withAttributes: [.foregroundColor: NSColor.white, .font: NSFont.boldSystemFont(ofSize: 28)])
        img.unlockFocus()
        let url = tmpDir().appendingPathComponent("\(name).png")
        if let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        }
        return Screenshot(url: url, captureDate: Date(timeIntervalSince1970: 1_700_000_000))
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
            PopoverRootView().environmentObject(controller).frame(width: 360, height: 320),
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
            PopoverRootView().environmentObject(controller).frame(width: 360, height: 320),
            to: "popover-no-access.png")
    }

    func testRenderNotSavingBanner() throws {
        try render(
            NotSavingBanner(onEnable: {}, onDisableThumbnail: {})
                .frame(width: 340).padding().background(Color(NSColor.windowBackgroundColor)),
            to: "banner-not-saving.png")
    }

    func testRenderFloatingPreview() throws {
        let shot = sample("preview", CGSize(width: 1280, height: 800), .systemIndigo)
        try render(FloatingPreview(screenshot: shot), to: "floating-preview.png")
    }
}

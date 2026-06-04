import XCTest
import AppKit
@testable import CopyCatKit

final class ThumbnailCacheTests: XCTestCase {
    /// Writes a large solid PNG to a temp file and returns its URL.
    private func makeLargePNG(_ size: NSSize) throws -> URL {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("copy-cat-thumb-\(UUID().uuidString).png")
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let rep = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try png.write(to: url)
        return url
    }

    func testThumbnailIsDownsampledToMaxPixel() throws {
        let url = try makeLargePNG(NSSize(width: 2400, height: 1600))
        let thumb = try XCTUnwrap(ThumbnailCache.shared.thumbnail(for: url, maxPixel: 256))
        // NSImage size is set to the decoded pixel dimensions.
        XCTAssertLessThanOrEqual(max(thumb.size.width, thumb.size.height), 256)
    }

    func testSecondLoadIsCached() throws {
        let url = try makeLargePNG(NSSize(width: 1200, height: 900))
        XCTAssertNil(ThumbnailCache.shared.cached(url, maxPixel: 200))
        _ = ThumbnailCache.shared.thumbnail(for: url, maxPixel: 200)
        XCTAssertNotNil(ThumbnailCache.shared.cached(url, maxPixel: 200))
    }

    func testMissingFileReturnsNil() {
        let url = URL(fileURLWithPath: "/nonexistent/copy-cat/\(UUID().uuidString).png")
        XCTAssertNil(ThumbnailCache.shared.thumbnail(for: url, maxPixel: 128))
    }
}

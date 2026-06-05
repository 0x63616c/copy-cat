import AppKit
import ImageIO

/// Loads downsampled thumbnails for screenshot files and caches them in memory.
///
/// The grid draws 88pt tiles; decoding a full multi-megapixel Retina screenshot
/// just to shrink it is the main source of lag. `CGImageSourceCreateThumbnail`
/// decodes only down to `maxPixel`, and the NSCache keeps already-made thumbs so
/// scrolling never re-decodes.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 600
    }

    private func key(_ url: URL, _ maxPixel: Int) -> NSString {
        "\(url.path)@\(maxPixel)" as NSString
    }

    /// Cache-only lookup (synchronous, cheap) for fast first paint.
    func cached(_ url: URL, maxPixel: Int) -> NSImage? {
        cache.object(forKey: key(url, maxPixel))
    }

    /// Decodes a downsampled thumbnail (call off the main thread). Returns nil if
    /// the file can't be read/decoded.
    func thumbnail(for url: URL, maxPixel: Int) -> NSImage? {
        if let hit = cached(url, maxPixel: maxPixel) { return hit }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixel),
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        cache.setObject(image, forKey: key(url, maxPixel))
        return image
    }

    private var pixelSizes: [String: CGSize] = [:]
    private let pixelSizeLock = NSLock()

    /// Reads a file's pixel dimensions from its header only (no decode). Cached.
    /// Returns nil if the file can't be read.
    func pixelSize(of url: URL) -> CGSize? {
        pixelSizeLock.lock()
        if let hit = pixelSizes[url.path] { pixelSizeLock.unlock(); return hit }
        pixelSizeLock.unlock()

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let h = props[kCGImagePropertyPixelHeight] as? CGFloat,
              w > 0, h > 0
        else { return nil }

        let size = CGSize(width: w, height: h)
        pixelSizeLock.lock()
        pixelSizes[url.path] = size
        pixelSizeLock.unlock()
        return size
    }
}

/// Fits `pixelSize` into a box whose longest side is `longest`, preserving aspect
/// ratio. Falls back to 4:3 when the size is unknown. Pure for testability.
func previewFittedSize(_ pixelSize: CGSize?, longest: CGFloat) -> CGSize {
    let raw = pixelSize ?? CGSize(width: 4, height: 3)
    let maxSide = max(raw.width, raw.height)
    guard maxSide > 0 else { return CGSize(width: longest, height: longest * 0.75) }
    let scale = longest / maxSide
    return CGSize(width: (raw.width * scale).rounded(), height: (raw.height * scale).rounded())
}

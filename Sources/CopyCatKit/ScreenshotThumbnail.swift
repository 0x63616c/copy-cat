import SwiftUI

/// Renders a downsampled, cached thumbnail for a screenshot file. Full-resolution
/// images are never decoded for display — only a thumbnail up to `maxPixel`.
struct ScreenshotImage: View {
    let url: URL
    var contentMode: ContentMode = .fill
    /// Largest pixel dimension to decode. Grid tiles use a small value; the
    /// floating preview uses a larger one.
    var maxPixel: Int = 256

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .task(id: taskID) {
            // Fast path: already cached, paint immediately, no thread hop.
            if let hit = ThumbnailCache.shared.cached(url, maxPixel: maxPixel) {
                image = hit
                return
            }
            let loaded = await Task.detached(priority: .userInitiated) {
                ThumbnailCache.shared.thumbnail(for: url, maxPixel: maxPixel)
            }.value
            image = loaded
        }
    }

    private var taskID: String { "\(url.path)@\(maxPixel)" }
}

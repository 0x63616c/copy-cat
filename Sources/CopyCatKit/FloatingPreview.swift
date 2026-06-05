import SwiftUI
import CopyCatCore

/// The large hover preview shown in a floating panel to the left of the popover.
/// The image shrink-wraps to the screenshot's real aspect ratio (no letterbox),
/// with the capture time and a compact "time ago" label.
struct FloatingPreview: View {
    let screenshot: Screenshot?
    /// Injected so the panel can size itself; defaults to live wall-clock.
    var now: Date = Date()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        if let shot = screenshot {
            let pixelSize = ThumbnailCache.shared.pixelSize(of: shot.url)
            let fitted = previewFittedSize(pixelSize, longest: PreviewMetrics.longestSide)

            VStack(alignment: .leading, spacing: 8) {
                ScreenshotImage(url: shot.url, contentMode: .fit,
                                maxPixel: Int(PreviewMetrics.longestSide * 2))
                    .frame(width: fitted.width, height: fitted.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 6) {
                    Text(Self.dateFormatter.string(from: shot.captureDate))
                    Text("(\(compactRelativeAge(from: shot.captureDate, now: now)))")
                        .monospacedDigit()
                    Spacer(minLength: 12)
                    if let pixelSize {
                        Text("\(Int(pixelSize.width))×\(Int(pixelSize.height))")
                            .monospacedDigit()
                    }
                }
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.78))
                .frame(width: fitted.width)
            }
            .padding(PreviewMetrics.padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PreviewMetrics.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PreviewMetrics.cornerRadius)
                    .strokeBorder(.separator, lineWidth: 1)
            )
            .shadow(radius: 18, y: 6)
            .padding(8) // room for the shadow inside the panel
        } else {
            EmptyView()
        }
    }
}

import SwiftUI
import CopyCatCore

/// The large hover preview shown in a floating panel to the left of the popover.
/// Native aspect ratio, letterboxed into a fixed 2x box, with the capture time.
struct FloatingPreview: View {
    let screenshot: Screenshot?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        if let shot = screenshot {
            VStack(alignment: .leading, spacing: 8) {
                ScreenshotImage(url: shot.url, contentMode: .fit,
                                maxPixel: Int(PreviewMetrics.imageWidth * 2))
                    .frame(width: PreviewMetrics.imageWidth, height: PreviewMetrics.imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(Self.dateFormatter.string(from: shot.captureDate))
                    .font(.callout)
                    .foregroundStyle(.secondary)
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

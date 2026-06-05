import SwiftUI
import AppKit
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
            // A real *behind-window* material: this card lives in a transparent
            // floating panel over the desktop, where SwiftUI's `.regularMaterial`
            // (within-window blending) has nothing to frost and renders invisible.
            // NSVisualEffectView blends against what's behind the window, and
            // degrades to a solid fill under Reduce Transparency on its own.
            .background(
                VisualEffectBackground(material: .popover, blending: .behindWindow)
                    .clipShape(RoundedRectangle(cornerRadius: PreviewMetrics.cornerRadius))
            )
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

/// Hosts an `NSVisualEffectView` so the floating preview card frosts against the
/// desktop behind its transparent panel (behind-window blending). Auto-degrades
/// to a solid fill when Reduce Transparency is on.
private struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blending
        nsView.state = .active
    }
}

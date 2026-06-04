import SwiftUI
import CopyCatCore

struct PreviewPane: View {
    let screenshot: Screenshot?
    let onReveal: (Screenshot) -> Void
    let onCopyPath: (Screenshot) -> Void
    let onCopyImage: (Screenshot) -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let shot = screenshot {
                ScreenshotImage(url: shot.url, contentMode: .fit)
                    .frame(maxWidth: 320, maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 8) {
                    Text(Self.dateFormatter.string(from: shot.captureDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button("Open in Finder") { onReveal(shot) }
                        Button("Copy path") { onCopyPath(shot) }
                        Button("Copy image") { onCopyImage(shot) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Rectangle().fill(.quaternary)
                    .frame(maxWidth: 320, maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
        }
        .frame(width: 340)
        .padding(12)
    }
}

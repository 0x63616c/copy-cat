import SwiftUI
import CopyCatCore

struct GridView: View {
    let screenshots: [Screenshot]
    let columns: Int
    let onHover: (Screenshot?) -> Void
    let onClick: (Screenshot) -> Void
    let onReveal: (Screenshot) -> Void
    let onCopyPath: (Screenshot) -> Void

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(PopoverMetrics.tile), spacing: PopoverMetrics.gap, alignment: .topLeading),
            count: max(1, columns)
        )
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: PopoverMetrics.gap) {
                ForEach(screenshots) { shot in
                    tile(shot)
                }
            }
            .padding(PopoverMetrics.gap)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func tile(_ shot: Screenshot) -> some View {
        ScreenshotImage(url: shot.url, contentMode: .fill, maxPixel: Int(PopoverMetrics.tile * 3))
            .frame(width: PopoverMetrics.tile, height: PopoverMetrics.tile)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onHover { inside in onHover(inside ? shot : nil) }
            .onTapGesture { onClick(shot) }
            .contextMenu {
                Button("Copy image") { onClick(shot) }
                Button("Open in Finder") { onReveal(shot) }
                Button("Copy path") { onCopyPath(shot) }
            }
            .help("Click to copy")
    }
}

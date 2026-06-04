import SwiftUI
import CopyCatCore

struct GridView: View {
    let screenshots: [Screenshot]
    let columns: Int
    let maxRows: Int
    let tileSize: CGFloat
    let spacing: CGFloat
    let onHover: (Screenshot?) -> Void
    let onClick: (Screenshot) -> Void

    private var layout: GridGeometry {
        gridLayout(itemCount: screenshots.count, columns: columns, maxRows: maxRows)
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(tileSize), spacing: spacing, alignment: .topLeading),
              count: layout.columns)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: layout.needsScroll) {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: spacing) {
                ForEach(screenshots) { shot in
                    ScreenshotImage(url: shot.url, contentMode: .fill)
                        .frame(width: tileSize, height: tileSize)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                        .onHover { inside in onHover(inside ? shot : nil) }
                        .onTapGesture { onClick(shot) }
                }
            }
            .padding(spacing)
        }
        .frame(
            width: CGFloat(layout.columns) * tileSize + CGFloat(layout.columns + 1) * spacing,
            height: CGFloat(layout.visibleRows) * tileSize + CGFloat(layout.visibleRows + 1) * spacing
        )
    }
}

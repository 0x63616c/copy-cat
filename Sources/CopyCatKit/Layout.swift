import CoreGraphics
import CopyCatCore

/// Shared layout constants for the popover, so the SwiftUI grid and the AppKit
/// popover sizing agree (no magic numbers split across files).
enum PopoverMetrics {
    static let tile: CGFloat = 88
    static let gap: CGFloat = 10
    static let headerHeight: CGFloat = 52
    static let bannerHeight: CGFloat = 60
    static let minWidth: CGFloat = 340
    static let minHeight: CGFloat = 300

    /// Width/height the popover should adopt for the current grid + state.
    static func size(columns: Int, rows: Int, count: Int, banner: Bool) -> CGSize {
        let g = gridLayout(itemCount: count, columns: columns, maxRows: rows)
        // LazyVGrid pads `gap` on every side, so add one extra gap each axis.
        let gridW = CGFloat(g.columns) * tile + CGFloat(g.columns + 1) * gap
        let gridH = CGFloat(g.visibleRows) * tile + CGFloat(g.visibleRows + 1) * gap
        let w = max(minWidth, gridW)
        let h = max(minHeight, headerHeight + (banner ? bannerHeight : 0) + gridH)
        return CGSize(width: w, height: h)
    }
}

/// Floating preview tooltip dimensions — 2x the previous inline preview (was
/// 320x240).
enum PreviewMetrics {
    static let imageWidth: CGFloat = 640
    static let imageHeight: CGFloat = 480
    static let padding: CGFloat = 14
    static let cornerRadius: CGFloat = 16
}

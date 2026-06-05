import CoreGraphics
import CopyCatCore

/// Shared layout constants for the popover, so the SwiftUI grid and the AppKit
/// popover sizing agree (no magic numbers split across files).
enum PopoverMetrics {
    static let tile: CGFloat = 88
    static let gap: CGFloat = 10
    /// Fixed height of the title-row content in each header bar (grid + settings),
    /// so the two titles line up regardless of which trailing control is present.
    static let headerRow: CGFloat = 34
    /// Full header height = headerRow + the bar's top/bottom padding (11 + 9).
    static let headerHeight: CGFloat = headerRow + 11 + 9
    static let bannerHeight: CGFloat = 60
    // Hug the fixed 4-column grid exactly (4 tiles + 5 gaps) so there is no
    // dead space between the last image and the scrollbar. The grid column is
    // pinned to this width so opening Settings doesn't reflow it.
    static let minWidth: CGFloat = 4 * tile + 5 * gap
    static let minHeight: CGFloat = 300

    /// Settings slides in as a pane on the right, matching the grid column width
    /// so the popover is symmetric and the grouped form isn't cramped.
    static let settingsPaneWidth: CGFloat = 4 * tile + 5 * gap
    /// Minimum popover height while the settings pane is open, so the form fits.
    static let settingsMinHeight: CGFloat = 470

    /// Width/height the popover should adopt for the current grid + state. When
    /// `settings` is true the right-hand settings pane is added beside the grid.
    static func size(columns: Int, rows: Int, count: Int, banner: Bool, settings: Bool) -> CGSize {
        let g = gridLayout(itemCount: count, columns: columns, maxRows: rows)
        // LazyVGrid pads `gap` on every side, so add one extra gap each axis.
        let gridW = CGFloat(g.columns) * tile + CGFloat(g.columns + 1) * gap
        let gridH = CGFloat(g.visibleRows) * tile + CGFloat(g.visibleRows + 1) * gap
        var w = max(minWidth, gridW)
        var h = max(minHeight, headerHeight + (banner ? bannerHeight : 0) + gridH)
        if settings {
            w += 1 + settingsPaneWidth   // +1 for the divider between grid and pane
            h = max(h, settingsMinHeight)
        }
        return CGSize(width: w, height: h)
    }
}

/// Floating preview tooltip dimensions. The image shrink-wraps to the
/// screenshot's real aspect ratio; `longestSide` caps its largest dimension.
enum PreviewMetrics {
    static let longestSide: CGFloat = 560
    static let padding: CGFloat = 14
    static let cornerRadius: CGFloat = 16
}

import Foundation

/// Resolved geometry for the screenshot grid.
public struct GridGeometry: Equatable, Sendable {
    public let columns: Int
    /// Rows actually shown (0...maxRows). Older rows beyond this scroll.
    public let visibleRows: Int
    /// True when there are more rows than fit, i.e. the grid must scroll.
    public let needsScroll: Bool
    /// Number of tiles in the final (newest-order, left-aligned) row.
    public let lastRowCount: Int

    public init(columns: Int, visibleRows: Int, needsScroll: Bool, lastRowCount: Int) {
        self.columns = columns
        self.visibleRows = visibleRows
        self.needsScroll = needsScroll
        self.lastRowCount = lastRowCount
    }
}

/// Computes grid geometry. Columns are fixed at `columns`; rows grow from 0 up
/// to `maxRows`, after which the grid scrolls. The last row is left-aligned and
/// may be partial (no empty placeholder tiles).
public func gridLayout(itemCount: Int, columns: Int, maxRows: Int) -> GridGeometry {
    let cols = max(1, columns)
    let cap = max(0, maxRows)
    let count = max(0, itemCount)

    guard count > 0 else {
        return GridGeometry(columns: cols, visibleRows: 0, needsScroll: false, lastRowCount: 0)
    }

    let rowsNeeded = (count + cols - 1) / cols
    let visibleRows = min(rowsNeeded, cap)
    let needsScroll = rowsNeeded > cap
    let remainder = count % cols
    let lastRowCount = remainder == 0 ? cols : remainder

    return GridGeometry(
        columns: cols,
        visibleRows: visibleRows,
        needsScroll: needsScroll,
        lastRowCount: lastRowCount
    )
}

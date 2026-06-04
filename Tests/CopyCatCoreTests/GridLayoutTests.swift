import Testing
@testable import CopyCatCore

@Test func emptyGridHasNoRows() {
    let g = gridLayout(itemCount: 0, columns: 3, maxRows: 5)
    #expect(g == GridGeometry(columns: 3, visibleRows: 0, needsScroll: false, lastRowCount: 0))
}

@Test func partialFirstRowIsLeftAligned() {
    let g = gridLayout(itemCount: 2, columns: 3, maxRows: 5)
    #expect(g == GridGeometry(columns: 3, visibleRows: 1, needsScroll: false, lastRowCount: 2))
}

@Test func fullRowReportsFullLastRowCount() {
    let g = gridLayout(itemCount: 6, columns: 3, maxRows: 5)
    #expect(g == GridGeometry(columns: 3, visibleRows: 2, needsScroll: false, lastRowCount: 3))
}

@Test func growsUpToMaxRowsThenScrolls() {
    let g = gridLayout(itemCount: 20, columns: 3, maxRows: 5)
    #expect(g.visibleRows == 5)
    #expect(g.needsScroll == true)
    #expect(g.lastRowCount == 2) // 20 % 3
}

@Test func exactlyAtCapDoesNotScroll() {
    let g = gridLayout(itemCount: 15, columns: 3, maxRows: 5)
    #expect(g.visibleRows == 5)
    #expect(g.needsScroll == false)
    #expect(g.lastRowCount == 3)
}

@Test func clampsNonPositiveColumnsToOne() {
    let g = gridLayout(itemCount: 4, columns: 0, maxRows: 5)
    #expect(g.columns == 1)
    #expect(g.visibleRows == 4)
}

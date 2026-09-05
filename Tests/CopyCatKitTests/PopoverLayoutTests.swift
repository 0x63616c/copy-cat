import Testing
import CopyCatCore
@testable import CopyCatKit

@Test func popoverFitsCardsAndKeepsLibraryStableWhenSettingsOpen() {
    let library = PopoverMetrics.size(columns: AppSettings.gridColumns, rows: AppSettings.gridRows, count: 100, banner: false, settings: false)
    let settings = PopoverMetrics.size(columns: AppSettings.gridColumns, rows: AppSettings.gridRows, count: 100, banner: false, settings: true)
    #expect(library.width == 392)
    #expect(library.height == 464)
    #expect(settings.width - library.width == 381)
    #expect(settings.height >= library.height)
    let empty = PopoverMetrics.size(columns: AppSettings.gridColumns, rows: AppSettings.gridRows, count: 0, banner: false, settings: false)
    #expect(empty.height - PopoverMetrics.headerHeight - PopoverMetrics.footerHeight >= 260)
}

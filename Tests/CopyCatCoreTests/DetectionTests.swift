import Foundation
import Testing
@testable import CopyCatCore

private func shot(_ path: String, _ t: TimeInterval) -> Screenshot {
    Screenshot(url: URL(fileURLWithPath: path), captureDate: Date(timeIntervalSince1970: t))
}

@Test func spotlightFlagWinsRegardlessOfName() {
    #expect(isScreenshot(isScreenCaptureFlag: true, fileName: "random.png") == true)
    #expect(isScreenshot(isScreenCaptureFlag: false, fileName: "Screenshot 1.png") == false)
}

@Test func fallsBackToFilenameWhenFlagUnknown() {
    #expect(isScreenshot(isScreenCaptureFlag: nil, fileName: "Screenshot 2026-06-04.png") == true)
    #expect(isScreenshot(isScreenCaptureFlag: nil, fileName: "CleanShot.png") == false)
}

private func entry(_ name: String, _ t: TimeInterval, regular: Bool = true) -> DirectoryEntry {
    DirectoryEntry(
        url: URL(fileURLWithPath: "/shots/\(name)"),
        name: name, isRegularFile: regular,
        modificationDate: Date(timeIntervalSince1970: t))
}

@Test func screenshotsFromEntriesKeepsOnlyScreenshotFilesNewestFirst() {
    let result = screenshots(fromEntries: [
        entry("Screenshot 2026-06-04.png", 10),
        entry("CleanShot.png", 99),                 // not a screenshot name
        entry("Screenshot 2026-06-06.png", 30),
        entry("Screenshot 2026-06-05.png", 20),
    ])
    #expect(result.map(\.url.lastPathComponent) == [
        "Screenshot 2026-06-06.png", "Screenshot 2026-06-05.png", "Screenshot 2026-06-04.png",
    ])
}

@Test func screenshotsFromEntriesSkipsDirectories() {
    let result = screenshots(fromEntries: [
        entry("Screenshot folder", 50, regular: false),
        entry("Screenshot real.png", 10),
    ])
    #expect(result.map(\.url.lastPathComponent) == ["Screenshot real.png"])
}

@Test func screenshotsFromEntriesEmptyWhenNoneMatch() {
    #expect(screenshots(fromEntries: [entry("photo.jpg", 1), entry("notes.txt", 2)]).isEmpty)
}

@Test func sortsNewestFirst() {
    let sorted = sortedNewestFirst([shot("/a", 10), shot("/b", 30), shot("/c", 20)])
    #expect(sorted.map(\.url.lastPathComponent) == ["b", "c", "a"])
}

@Test func newScreenshotsReturnsOnlyUnseenNewestFirst() {
    let previous: Set<String> = ["/a"]
    let current = [shot("/a", 10), shot("/b", 30), shot("/c", 20)]
    let fresh = newScreenshots(previousIDs: previous, current: current)
    #expect(fresh.map(\.url.lastPathComponent) == ["b", "c"])
}

@Test func noNewScreenshotsWhenAllSeen() {
    let fresh = newScreenshots(previousIDs: ["/a", "/b"], current: [shot("/a", 1), shot("/b", 2)])
    #expect(fresh.isEmpty)
}

@Test func mostRecentCapsToNewestN() {
    let items = (0..<10).map { shot("/\($0)", TimeInterval($0)) }
    let top3 = mostRecent(items, limit: 3)
    #expect(top3.map(\.url.lastPathComponent) == ["9", "8", "7"])
}

@Test func mostRecentReturnsAllWhenUnderLimit() {
    let items = [shot("/a", 1), shot("/b", 2)]
    #expect(mostRecent(items, limit: 50).count == 2)
}

@Test func mostRecentZeroLimitIsEmpty() {
    #expect(mostRecent([shot("/a", 1)], limit: 0).isEmpty)
}

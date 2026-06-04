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

import Testing
@testable import CopyCatCore

@Test func noAccessTrumpsEverythingAndPausesCopy() {
    let s = resolveStatus(hasAccess: false, savingToDisk: true, screenshotCount: 9)
    #expect(s.content == .noAccess)
    #expect(s.autoCopyPaused == true)
    #expect(s.showNotSavingBanner == false)
}

@Test func emptyWhenAccessibleButNoScreenshots() {
    let s = resolveStatus(hasAccess: true, savingToDisk: true, screenshotCount: 0)
    #expect(s.content == .empty)
    #expect(s.autoCopyPaused == false)
    #expect(s.showNotSavingBanner == false)
}

@Test func normalWhenAccessibleWithScreenshots() {
    let s = resolveStatus(hasAccess: true, savingToDisk: true, screenshotCount: 3)
    #expect(s.content == .normal)
    #expect(s.showNotSavingBanner == false)
}

@Test func notSavingBannerShowsOverContentWhenAccessible() {
    let s = resolveStatus(hasAccess: true, savingToDisk: false, screenshotCount: 3)
    #expect(s.content == .normal)
    #expect(s.showNotSavingBanner == true)
    #expect(s.autoCopyPaused == false)
}

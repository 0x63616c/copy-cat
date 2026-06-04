import Foundation
import Testing
import CopyCatCore
@testable import CopyCatKit

private func shot(_ path: String, _ t: TimeInterval = 0) -> Screenshot {
    Screenshot(url: URL(fileURLWithPath: path), captureDate: Date(timeIntervalSince1970: t))
}

@MainActor
private func makeController(clipboard: FakeClipboard, prefs: FakePrefs, access: FakeAccess) -> AppController {
    AppController(store: makeTempStore(), clipboard: clipboard, prefs: prefs, access: access)
}

@Test @MainActor func newScreenshotIsCopiedWhenEnabled() {
    let clip = FakeClipboard()
    let c = makeController(clipboard: clip, prefs: FakePrefs(), access: FakeAccess())
    c.handleNew([shot("/a", 2), shot("/b", 1)])
    #expect(clip.copied == [URL(fileURLWithPath: "/a")]) // newest only
}

@Test @MainActor func newScreenshotIsNotCopiedWhenToggleOff() {
    let clip = FakeClipboard()
    let c = makeController(clipboard: clip, prefs: FakePrefs(), access: FakeAccess())
    var s = c.settings; s.copyOnScreenshot = false; c.updateSettings(s)
    c.handleNew([shot("/a", 2)])
    #expect(clip.copied.isEmpty)
}

@Test @MainActor func autoCopyPausesWithoutAccessAndBackfillsOnResume() {
    let clip = FakeClipboard()
    let access = FakeAccess()
    let c = makeController(clipboard: clip, prefs: FakePrefs(), access: access)

    access.readable = false
    c.refreshStatus()
    #expect(c.status.autoCopyPaused == true)

    c.handleNew([shot("/late", 5)]) // arrives while paused
    #expect(clip.copied.isEmpty)

    access.readable = true
    c.refreshStatus()                // resume -> back-fill
    #expect(clip.copied == [URL(fileURLWithPath: "/late")])
}

@Test @MainActor func clickingATileCopiesIt() {
    let clip = FakeClipboard()
    let c = makeController(clipboard: clip, prefs: FakePrefs(), access: FakeAccess())
    c.copy(shot("/clicked"))
    #expect(clip.copied == [URL(fileURLWithPath: "/clicked")])
}

@Test @MainActor func enableFileTargetFlipsPrefAndClearsBanner() {
    let prefs = FakePrefs()
    prefs.target = "clipboard"
    let c = makeController(clipboard: FakeClipboard(), prefs: prefs, access: FakeAccess())
    c.refreshStatus()
    #expect(c.status.showNotSavingBanner == true)
    c.enableFileTarget()
    #expect(prefs.fileTargetEnabled == true)
    #expect(c.status.showNotSavingBanner == false)
}

import Foundation
import Testing
@testable import CopyCatCore

@Test func defaultsMatchSpec() {
    let d = AppSettings.defaults
    #expect(d.copyOnScreenshot == true)
    #expect(d.gridColumns == 3)
    #expect(d.gridRows == 5)
    #expect(d.saveLocationPath == nil)
}

@Test func settingsRoundTripThroughJSON() throws {
    var s = AppSettings.defaults
    s.copyOnScreenshot = false
    s.gridColumns = 4
    s.gridRows = 6
    s.saveLocationPath = "/Users/x/Pictures/Screenshots"
    let data = try JSONEncoder().encode(s)
    let back = try JSONDecoder().decode(AppSettings.self, from: data)
    #expect(back == s)
}

@Test func gridDimensionsClampToSaneRange() {
    var s = AppSettings.defaults
    s.gridColumns = 0
    s.gridRows = 99
    let clamped = s.clamped()
    #expect(clamped.gridColumns >= 1)
    #expect(clamped.gridRows <= 12)
}

@Test func configURLLivesUnderApplicationSupport() {
    let url = AppSettings.configURL()
    #expect(url.path.contains("Application Support/copy-cat"))
    #expect(url.lastPathComponent == "config.json")
}

@Test func storeSavesAndLoadsFromDisk() throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("copy-cat-test-\(UUID().uuidString)")
        .appendingPathComponent("config.json")
    let store = SettingsStore(url: tmp)
    var s = AppSettings.defaults
    s.gridColumns = 4
    try store.save(s)
    #expect(store.load().gridColumns == 4)
}

import Foundation
import Testing
@testable import CopyCatCore

@Test func defaultsMatchSpec() {
    let d = AppSettings.defaults
    #expect(d.copyOnScreenshot == true)
    #expect(d.saveLocationPath == nil)
}

@Test func gridIsFixedFourByFour() {
    #expect(AppSettings.gridColumns == 4)
    #expect(AppSettings.gridRows == 4)
}

@Test func settingsRoundTripThroughJSON() throws {
    var s = AppSettings.defaults
    s.copyOnScreenshot = false
    s.saveLocationPath = "/Users/x/Pictures/Screenshots"
    let data = try JSONEncoder().encode(s)
    let back = try JSONDecoder().decode(AppSettings.self, from: data)
    #expect(back == s)
}

/// Old configs carried gridColumns/gridRows keys; decoding must ignore them.
@Test func decodingIgnoresLegacyGridKeys() throws {
    let json = """
    {"copyOnScreenshot": false, "gridColumns": 7, "gridRows": 9}
    """.data(using: .utf8)!
    let s = try JSONDecoder().decode(AppSettings.self, from: json)
    #expect(s.copyOnScreenshot == false)
    #expect(s.saveLocationPath == nil)
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
    s.copyOnScreenshot = false
    s.saveLocationPath = "/tmp/shots"
    try store.save(s)
    let loaded = store.load()
    #expect(loaded.copyOnScreenshot == false)
    #expect(loaded.saveLocationPath == "/tmp/shots")
}

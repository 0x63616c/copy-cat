import Foundation
import CopyCatCore
@testable import CopyCatKit

final class FakeClipboard: Clipboard, @unchecked Sendable {
    var copied: [URL] = []
    func copyImage(at url: URL) -> Bool { copied.append(url); return true }
}

final class FakePrefs: ScreencapturePreferences, @unchecked Sendable {
    var locationPath: String? = "/tmp/copy-cat-shots"
    var target: String? = "file"
    private(set) var fileTargetEnabled = false
    private(set) var thumbnailDisabled = false
    func enableFileTarget() { fileTargetEnabled = true; target = "file" }
    func disableThumbnail() { thumbnailDisabled = true }
}

final class FakeAccess: FolderAccessing, @unchecked Sendable {
    var readable = true
    func canRead(path: String) -> Bool { readable }
    func saveBookmark(for url: URL) {}
    func resolveBookmark() -> URL? { nil }
    func escapeHatchFolder() -> URL { URL(fileURLWithPath: "/tmp/copy-cat-escape") }
}

/// A SettingsStore backed by a throwaway temp file.
func makeTempStore() -> SettingsStore {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("copy-cat-test-\(UUID().uuidString)")
        .appendingPathComponent("config.json")
    return SettingsStore(url: url)
}

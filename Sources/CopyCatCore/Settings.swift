import Foundation

/// User-configurable settings, persisted as JSON under Application Support.
/// Named `AppSettings` to avoid colliding with SwiftUI's `Settings` scene.
public struct AppSettings: Codable, Equatable, Sendable {
    public var copyOnScreenshot: Bool
    /// Folder to watch. `nil` means "use the macOS screencapture location".
    public var saveLocationPath: String?

    public init(copyOnScreenshot: Bool, saveLocationPath: String?) {
        self.copyOnScreenshot = copyOnScreenshot
        self.saveLocationPath = saveLocationPath
    }

    public static let defaults = AppSettings(
        copyOnScreenshot: true,
        saveLocationPath: nil
    )

    /// The screenshot grid is a fixed 4×4: four columns, four visible rows
    /// before it scrolls. Not user-configurable.
    public static let gridColumns = 4
    public static let gridRows = 4

    /// `~/Library/Application Support/copy-cat/config.json`
    public static func configURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("copy-cat", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }
}

/// Loads and saves `AppSettings` to disk, falling back to defaults on any error.
public struct SettingsStore: Sendable {
    private let url: URL

    public init(url: URL = AppSettings.configURL()) {
        self.url = url
    }

    public func load() -> AppSettings {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .defaults
        }
        return decoded
    }

    public func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: url, options: .atomic)
    }
}

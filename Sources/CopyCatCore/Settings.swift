import Foundation

/// User-configurable settings, persisted as JSON under Application Support.
/// Named `AppSettings` to avoid colliding with SwiftUI's `Settings` scene.
public struct AppSettings: Codable, Equatable, Sendable {
    public var copyOnScreenshot: Bool
    /// Folder to watch. `nil` means "use the macOS screencapture location".
    public var saveLocationPath: String?
    public var gridColumns: Int
    public var gridRows: Int

    public init(copyOnScreenshot: Bool, saveLocationPath: String?, gridColumns: Int, gridRows: Int) {
        self.copyOnScreenshot = copyOnScreenshot
        self.saveLocationPath = saveLocationPath
        self.gridColumns = gridColumns
        self.gridRows = gridRows
    }

    public static let defaults = AppSettings(
        copyOnScreenshot: true,
        saveLocationPath: nil,
        gridColumns: 3,
        gridRows: 5
    )

    /// Smallest and largest grid dimension the popover supports (square range).
    public static let minDimension = 3
    public static let maxDimension = 10

    /// Clamps grid dimensions to a usable range for the popover.
    public func clamped() -> AppSettings {
        var copy = self
        copy.gridColumns = min(max(Self.minDimension, gridColumns), Self.maxDimension)
        copy.gridRows = min(max(Self.minDimension, gridRows), Self.maxDimension)
        return copy
    }

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
        return decoded.clamped()
    }

    public func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings.clamped()).write(to: url, options: .atomic)
    }
}

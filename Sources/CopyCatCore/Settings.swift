import Foundation

/// User-configurable settings, persisted as JSON under Application Support.
/// Named `AppSettings` to avoid colliding with SwiftUI's `Settings` scene.
public struct AppSettings: Codable, Equatable, Sendable {
    public var copyOnScreenshot: Bool
    /// Folder to watch. `nil` means "use the macOS screencapture location".
    public var saveLocationPath: String?

    /// Global hotkey that opens the menu-bar popover. Default: Hyper+X.
    public var openMenuShortcut: HotKey
    /// Global hotkey that copies the newest screenshot to the clipboard. Default: Hyper+C.
    public var copyLastShortcut: HotKey

    public init(
        copyOnScreenshot: Bool,
        saveLocationPath: String?,
        openMenuShortcut: HotKey = .hyper(7),   // X
        copyLastShortcut: HotKey = .hyper(8)    // C
    ) {
        self.copyOnScreenshot = copyOnScreenshot
        self.saveLocationPath = saveLocationPath
        self.openMenuShortcut = openMenuShortcut
        self.copyLastShortcut = copyLastShortcut
    }

    // Backward-compatible decode: configs written before shortcuts existed have
    // no `openMenuShortcut`/`copyLastShortcut` keys. Decode them as optional and
    // fall back to the Hyper defaults so an old config keeps its other settings
    // instead of the whole struct failing to decode and resetting everything.
    private enum CodingKeys: String, CodingKey {
        case copyOnScreenshot, saveLocationPath, openMenuShortcut, copyLastShortcut
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.copyOnScreenshot = try c.decode(Bool.self, forKey: .copyOnScreenshot)
        self.saveLocationPath = try c.decodeIfPresent(String.self, forKey: .saveLocationPath)
        self.openMenuShortcut = try c.decodeIfPresent(HotKey.self, forKey: .openMenuShortcut) ?? .hyper(7)
        self.copyLastShortcut = try c.decodeIfPresent(HotKey.self, forKey: .copyLastShortcut) ?? .hyper(8)
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

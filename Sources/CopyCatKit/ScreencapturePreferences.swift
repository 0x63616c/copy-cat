import Foundation
import CopyCatCore

/// Read/write access to the macOS screenshot preferences domain.
public protocol ScreencapturePreferences: Sendable {
    var locationPath: String? { get }
    var target: String? { get }
    func enableFileTarget()
    func disableThumbnail()
}

public extension ScreencapturePreferences {
    /// Is macOS currently saving screenshots to disk?
    var isSavingToDisk: Bool { savingToDisk(target: target) }

    /// The resolved folder to watch when settings don't override it.
    func resolvedLocation(home: String) -> String {
        locationPath ?? "\(home)/Desktop"
    }
}

public struct SystemScreencapturePreferences: ScreencapturePreferences {
    private let domain = "com.apple.screencapture"
    private var defaults: UserDefaults? { UserDefaults(suiteName: domain) }

    public init() {}

    public var locationPath: String? {
        guard let raw = defaults?.string(forKey: "location"), !raw.isEmpty else { return nil }
        return (raw as NSString).expandingTildeInPath
    }

    public var target: String? {
        let raw = defaults?.string(forKey: "target")
        return (raw?.isEmpty ?? true) ? nil : raw
    }

    public func enableFileTarget() {
        defaults?.set("file", forKey: "target")
        defaults?.synchronize()
    }

    public func disableThumbnail() {
        defaults?.set(false, forKey: "show-thumbnail")
        defaults?.synchronize()
    }
}

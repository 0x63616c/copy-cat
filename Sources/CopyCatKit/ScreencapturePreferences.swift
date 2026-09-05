import Foundation
import CopyCatCore

/// Read/write access to the macOS screenshot preferences domain.
public protocol ScreencapturePreferences: Sendable {
    var locationPath: String? { get }
    var target: String? { get }
    var hidesFloatingThumbnail: Bool { get }
    func enableFileTarget()
    func disableThumbnail()
    func setHidesFloatingThumbnail(_ hide: Bool)
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

    public var hidesFloatingThumbnail: Bool {
        Self.hidesFloatingThumbnail(showThumbnail: defaults?.object(forKey: "show-thumbnail") as? Bool)
    }

    static func hidesFloatingThumbnail(showThumbnail: Bool?) -> Bool {
        // macOS shows the thumbnail unless the preference explicitly disables it.
        showThumbnail.map { !$0 } ?? false
    }

    public func enableFileTarget() {
        defaults?.set("file", forKey: "target")
        defaults?.synchronize()
    }

    public func disableThumbnail() {
        setHidesFloatingThumbnail(true)
    }

    public func setHidesFloatingThumbnail(_ hide: Bool) {
        defaults?.set(!hide, forKey: "show-thumbnail")
        defaults?.synchronize()
    }
}

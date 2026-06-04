import Foundation

/// Which content region fills the popover body.
public enum ContentState: Equatable, Sendable {
    case noAccess   // folder is TCC-protected and denied; recovery routes
    case empty      // accessible, but zero screenshots
    case normal     // accessible, grid + preview
}

/// Full derived UI state for the popover.
public struct AppStatus: Equatable, Sendable {
    public let content: ContentState
    public let showNotSavingBanner: Bool
    public let autoCopyPaused: Bool

    public init(content: ContentState, showNotSavingBanner: Bool, autoCopyPaused: Bool) {
        self.content = content
        self.showNotSavingBanner = showNotSavingBanner
        self.autoCopyPaused = autoCopyPaused
    }
}

/// Derives the popover state. Access is the highest-priority signal: with no
/// access we show the recovery state and pause auto-copy. Otherwise content is
/// empty vs normal by count, and the not-saving banner overlays either.
public func resolveStatus(
    hasAccess: Bool,
    savingToDisk: Bool,
    screenshotCount: Int
) -> AppStatus {
    guard hasAccess else {
        return AppStatus(content: .noAccess, showNotSavingBanner: false, autoCopyPaused: true)
    }
    let content: ContentState = screenshotCount > 0 ? .normal : .empty
    return AppStatus(
        content: content,
        showNotSavingBanner: !savingToDisk,
        autoCopyPaused: false
    )
}

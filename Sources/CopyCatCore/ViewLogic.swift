import Foundation

/// The screenshot the preview pane should show: the hovered tile if any,
/// otherwise the newest (so the pane is never blank).
public func previewTarget(hovered: Screenshot?, newest: Screenshot?) -> Screenshot? {
    hovered ?? newest
}

/// SF Symbol name for the menu bar item. A black cat normally; a warning badge
/// while folder access is unresolved.
public func badgeSymbolName(for content: ContentState) -> String {
    content == .noAccess ? "exclamationmark.triangle.fill" : "cat.fill"
}

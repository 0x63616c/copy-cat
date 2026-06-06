import Foundation

/// Decides whether a file is a screenshot. The Spotlight
/// `kMDItemIsScreenCapture` flag is authoritative; when it is unavailable
/// (Spotlight disabled for the location) we fall back to the macOS default
/// "Screenshot*" filename heuristic.
public func isScreenshot(isScreenCaptureFlag: Bool?, fileName: String) -> Bool {
    if let flag = isScreenCaptureFlag {
        return flag
    }
    return fileName.hasPrefix("Screenshot")
}

/// One raw directory entry, as read straight off the filesystem. Used by the
/// Spotlight-independent folder watcher so the screenshot-filtering decision can
/// live here in pure, tested code rather than tangled with FS-enumeration glue.
public struct DirectoryEntry: Sendable {
    public let url: URL
    public let name: String
    public let isRegularFile: Bool
    public let modificationDate: Date

    public init(url: URL, name: String, isRegularFile: Bool, modificationDate: Date) {
        self.url = url
        self.name = name
        self.isRegularFile = isRegularFile
        self.modificationDate = modificationDate
    }
}

/// Turns raw directory entries into the newest-first screenshot list. Filters to
/// regular files that look like screenshots. The Spotlight `kMDItemIsScreenCapture`
/// flag is unavailable when reading the filesystem directly, so this passes `nil`
/// and `isScreenshot` falls back to the filename heuristic — which is exactly the
/// resilience we want: detection no longer depends on Spotlight indexing.
public func screenshots(fromEntries entries: [DirectoryEntry]) -> [Screenshot] {
    let shots = entries.compactMap { entry -> Screenshot? in
        guard entry.isRegularFile else { return nil }
        guard isScreenshot(isScreenCaptureFlag: nil, fileName: entry.name) else { return nil }
        return Screenshot(url: entry.url, captureDate: entry.modificationDate)
    }
    return sortedNewestFirst(shots)
}

/// Newest capture first.
public func sortedNewestFirst(_ items: [Screenshot]) -> [Screenshot] {
    items.sorted { $0.captureDate > $1.captureDate }
}

/// Returns items not present in `previousIDs`, newest first.
public func newScreenshots(previousIDs: Set<String>, current: [Screenshot]) -> [Screenshot] {
    sortedNewestFirst(current.filter { !previousIDs.contains($0.id) })
}

/// The newest `limit` screenshots, newest first. Caps how many tiles the grid
/// ever holds so work stays bounded no matter how many files are on disk.
public func mostRecent(_ items: [Screenshot], limit: Int) -> [Screenshot] {
    guard limit > 0 else { return [] }
    return Array(sortedNewestFirst(items).prefix(limit))
}

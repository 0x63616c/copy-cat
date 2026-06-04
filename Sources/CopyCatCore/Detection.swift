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

/// Newest capture first.
public func sortedNewestFirst(_ items: [Screenshot]) -> [Screenshot] {
    items.sorted { $0.captureDate > $1.captureDate }
}

/// Returns items not present in `previousIDs`, newest first.
public func newScreenshots(previousIDs: Set<String>, current: [Screenshot]) -> [Screenshot] {
    sortedNewestFirst(current.filter { !previousIDs.contains($0.id) })
}

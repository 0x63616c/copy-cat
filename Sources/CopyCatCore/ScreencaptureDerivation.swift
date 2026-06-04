import Foundation

/// True when `path` lives inside a TCC-protected zone (Desktop, Documents,
/// Downloads) where a background process needs explicit consent to read.
public func isProtectedLocation(_ path: String, home: String) -> Bool {
    let normalized = (path as NSString).standardizingPath
    for zone in ["Desktop", "Documents", "Downloads"] {
        let root = "\(home)/\(zone)"
        if normalized == root || normalized.hasPrefix(root + "/") {
            return true
        }
    }
    return false
}

/// Whether macOS will write screenshots to a file. `com.apple.screencapture`
/// `target` defaults to `file` when unset; any non-file target (e.g.
/// `clipboard`, `preview`) means nothing lands on disk.
public func savingToDisk(target: String?) -> Bool {
    guard let target, !target.isEmpty else { return true }
    return target == "file"
}

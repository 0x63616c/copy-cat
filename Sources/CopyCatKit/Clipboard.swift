import AppKit

/// Copies an image file's contents onto the system pasteboard.
public protocol Clipboard: Sendable {
    @discardableResult
    func copyImage(at url: URL) -> Bool
}

public struct NSPasteboardClipboard: Clipboard {
    public init() {}

    @discardableResult
    public func copyImage(at url: URL) -> Bool {
        guard let image = NSImage(contentsOf: url) else { return false }
        let pb = NSPasteboard.general
        pb.clearContents()
        return pb.writeObjects([image])
    }
}

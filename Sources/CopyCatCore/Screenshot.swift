import Foundation

/// A single screenshot on disk. Identity is the file path so the same file
/// compares equal regardless of metadata we attach to it.
public struct Screenshot: Identifiable, Hashable, Sendable {
    public let url: URL
    public let captureDate: Date

    public init(url: URL, captureDate: Date) {
        self.url = url
        self.captureDate = captureDate
    }

    public var id: String { url.path }

    public static func == (lhs: Screenshot, rhs: Screenshot) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

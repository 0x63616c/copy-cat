import AppKit

/// Abstracts folder-access probing + consent persistence so the coordinator can
/// be tested with a fake.
public protocol FolderAccessing: Sendable {
    func canRead(path: String) -> Bool
    func saveBookmark(for url: URL)
    func resolveBookmark() -> URL?
    func escapeHatchFolder() -> URL
}

public struct FolderAccess: FolderAccessing {
    private let bookmarkURL: URL

    public init(bookmarkURL: URL = FolderAccess.defaultBookmarkURL()) {
        self.bookmarkURL = bookmarkURL
    }

    public static func defaultBookmarkURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("copy-cat", isDirectory: true)
            .appendingPathComponent("folder.bookmark", isDirectory: false)
    }

    public func canRead(path: String) -> Bool {
        FileManager.default.isReadableFile(atPath: path)
            && (try? FileManager.default.contentsOfDirectory(atPath: path)) != nil
    }

    public func saveBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        try? FileManager.default.createDirectory(
            at: bookmarkURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: bookmarkURL, options: .atomic)
    }

    public func resolveBookmark() -> URL? {
        guard let data = try? Data(contentsOf: bookmarkURL) else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    public func escapeHatchFolder() -> URL {
        let url = FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

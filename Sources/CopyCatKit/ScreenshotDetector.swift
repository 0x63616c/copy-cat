import Foundation
import CopyCatCore

/// Live folder watcher built on Spotlight. Emits the full newest-first list on
/// every change and separately reports newly-arrived screenshots.
///
/// `NSMetadataQuery` delivers its notifications on the main run loop, so the
/// whole type is main-actor isolated and its callbacks fire on the main actor.
@MainActor
public final class ScreenshotDetector {
    public var onUpdate: (([Screenshot]) -> Void)?
    public var onNewScreenshots: (([Screenshot]) -> Void)?

    private let query = NSMetadataQuery()
    private var knownIDs: Set<String> = []
    private var folderPath: String

    public init(folderPath: String) {
        self.folderPath = folderPath
        NotificationCenter.default.addObserver(
            self, selector: #selector(handle(_:)),
            name: .NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handle(_:)),
            name: .NSMetadataQueryDidUpdate, object: query)
    }

    public func start() {
        query.stop()
        knownIDs = []
        query.searchScopes = [folderPath]
        query.predicate = NSPredicate(
            format: "kMDItemIsScreenCapture == 1 || kMDItemFSName LIKE 'Screenshot*'")
        query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false)]
        query.start()
    }

    public func update(folderPath: String) {
        self.folderPath = folderPath
        start()
    }

    public func stop() { query.stop() }

    @objc private func handle(_ note: Notification) {
        query.disableUpdates()
        defer { query.enableUpdates() }

        var shots: [Screenshot] = []
        for i in 0..<query.resultCount {
            guard let item = query.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
            else { continue }
            let name = item.value(forAttribute: NSMetadataItemFSNameKey) as? String ?? ""
            let flag = item.value(forAttribute: "kMDItemIsScreenCapture") as? Bool
            guard isScreenshot(isScreenCaptureFlag: flag, fileName: name) else { continue }
            let date = (item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date) ?? .distantPast
            shots.append(Screenshot(url: URL(fileURLWithPath: path), captureDate: date))
        }

        let sorted = sortedNewestFirst(shots)
        let fresh = newScreenshots(previousIDs: knownIDs, current: shots)
        knownIDs = Set(shots.map(\.id))

        onUpdate?(sorted)
        if !fresh.isEmpty { onNewScreenshots?(fresh) }
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}

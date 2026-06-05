import Foundation
import CopyCatCore

/// Wraps `NSMetadataItem`s so a snapshot can cross to a background queue under
/// Swift 6 strict concurrency. Safe because the items are immutable snapshots
/// captured while query updates are disabled.
private struct ItemBox: @unchecked Sendable {
    let items: [NSMetadataItem]
}

/// Live folder watcher built on Spotlight. Emits the full newest-first list on
/// every change and reports a newly-arrived screenshot.
///
/// `NSMetadataQuery` delivers notifications on the main run loop. Parsing the
/// results (which can be thousands of files) is dispatched to a background queue
/// so it never blocks the UI; only the finished result is handed back to the
/// main actor.
///
/// The list is *not* capped: the grid is virtualized (`LazyVGrid` realizes only
/// on-screen tiles) and the decoded-thumbnail cache is bounded independently, so
/// the cost is set by what's visible, not by how many files exist. An optional
/// `displayLimit` remains as a safety valve for pathological folders; `nil`
/// (the default) means show every screenshot.
@MainActor
public final class ScreenshotDetector {
    public var onUpdate: (([Screenshot]) -> Void)?
    public var onNewScreenshots: (([Screenshot]) -> Void)?

    private let query = NSMetadataQuery()
    private let displayLimit: Int?
    private var folderPath: String
    /// Identity of the newest screenshot we've delivered, for O(1) new-detection.
    private var lastNewestID: String?
    /// Becomes true after the first gather so we don't "copy" a pre-existing shot.
    private var hasGathered = false

    public init(folderPath: String, displayLimit: Int? = nil) {
        self.folderPath = folderPath
        self.displayLimit = displayLimit
        NotificationCenter.default.addObserver(
            self, selector: #selector(handle(_:)),
            name: .NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handle(_:)),
            name: .NSMetadataQueryDidUpdate, object: query)
    }

    public func start() {
        query.stop()
        lastNewestID = nil
        hasGathered = false
        query.searchScopes = [folderPath]
        query.predicate = NSPredicate(
            format: "kMDItemIsScreenCapture == 1 || kMDItemFSName LIKE 'Screenshot*'")
        // Pre-sorted newest-first so the capped prefix is the newest files.
        query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false)]
        // Prefetch the attributes we read so off-main access is cached dict reads.
        query.valueListAttributes = [
            NSMetadataItemPathKey, NSMetadataItemFSNameKey,
            NSMetadataItemFSContentChangeDateKey, "kMDItemIsScreenCapture",
        ]
        // Coalesce bursts (e.g. importing many files) into one update.
        query.notificationBatchingInterval = 0.25
        query.start()
    }

    public func update(folderPath: String) {
        self.folderPath = folderPath
        start()
    }

    public func stop() { query.stop() }

    @objc private func handle(_ note: Notification) {
        query.disableUpdates()
        let box = ItemBox(items: (query.results as? [NSMetadataItem]) ?? [])
        query.enableUpdates()
        let limit = displayLimit

        DispatchQueue.global(qos: .userInitiated).async {
            let parsed = Self.parse(box.items)
            // Spotlight pre-sorts newest-first, but re-sort to be order-independent.
            let ordered = limit.map { mostRecent(parsed, limit: $0) } ?? sortedNewestFirst(parsed)
            let newest = ordered.first
            Task { @MainActor [weak self] in
                self?.deliver(ordered: ordered, newest: newest)
            }
        }
    }

    private func deliver(ordered: [Screenshot], newest: Screenshot?) {
        onUpdate?(ordered)
        if let newest, newest.id != lastNewestID {
            if hasGathered { onNewScreenshots?([newest]) }
            lastNewestID = newest.id
        }
        hasGathered = true
    }

    /// Parses metadata items into screenshots. `nonisolated static` so it can run
    /// on a background queue.
    nonisolated private static func parse(_ items: [NSMetadataItem]) -> [Screenshot] {
        var shots: [Screenshot] = []
        shots.reserveCapacity(items.count)
        for item in items {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { continue }
            let name = item.value(forAttribute: NSMetadataItemFSNameKey) as? String ?? ""
            let flag = item.value(forAttribute: "kMDItemIsScreenCapture") as? Bool
            guard isScreenshot(isScreenCaptureFlag: flag, fileName: name) else { continue }
            let date = (item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date) ?? .distantPast
            shots.append(Screenshot(url: URL(fileURLWithPath: path), captureDate: date))
        }
        return shots
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}

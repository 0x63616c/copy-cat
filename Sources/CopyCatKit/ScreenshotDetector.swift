import Foundation
import CopyCatCore

/// Live folder watcher that reads the filesystem **directly** — no Spotlight.
///
/// History: this used to be an `NSMetadataQuery` (a live Spotlight query). That
/// made the entire app silently dependent on Spotlight indexing the watch
/// folder. When macOS dropped indexing on `~/Screenshots` ("unknown indexing
/// state"), new screenshots stopped appearing in the UI and auto-copy died, with
/// no error anywhere. Spotlight is exactly the kind of "bullshit" we never want
/// to depend on again.
///
/// This implementation has two independent legs so a single failure can't blind
/// the app:
///   1. A `DispatchSource` vnode watch on the folder's file descriptor for
///      instant reaction when entries are added/renamed/removed.
///   2. A low-frequency poll timer as a safety net that re-scans regardless of
///      whether any event fired (covers missed events, network volumes, etc.).
///
/// Both legs converge on the same debounced `runScan`, which enumerates the
/// directory with `FileManager` and hands the result to `CopyCatCore` for the
/// (pure, tested) screenshot-filtering decision. Detection now works whether or
/// not Spotlight is indexing anything.
@MainActor
public final class ScreenshotDetector {
    public var onUpdate: (([Screenshot]) -> Void)?
    public var onNewScreenshots: (([Screenshot]) -> Void)?

    private let displayLimit: Int?
    private var folderPath: String
    /// Identity of the newest screenshot we've delivered, for O(1) new-detection.
    private var lastNewestID: String?
    /// Becomes true after the first scan so we don't "copy" a pre-existing shot.
    private var hasGathered = false

    /// vnode watch on the folder fd.
    private var source: DispatchSourceFileSystemObject?
    /// Periodic safety-net re-scan, independent of vnode events.
    private var pollTimer: DispatchSourceTimer?
    /// Pending debounce, so a burst of vnode events coalesces into one scan.
    private var debounceTask: Task<Void, Never>?
    /// Serializes the (blocking) FS enumeration off the main actor.
    private let scanQueue = DispatchQueue(label: "co.copycat.folderwatcher.scan", qos: .userInitiated)

    /// How often the safety-net poll re-scans even if no event fired.
    private let pollInterval: TimeInterval = 4
    /// Coalesce window for bursts of vnode events (temp-file + rename, etc.).
    private let debounce: TimeInterval = 0.2

    public init(folderPath: String, displayLimit: Int? = nil) {
        self.folderPath = folderPath
        self.displayLimit = displayLimit
    }

    public func start() {
        stop()
        lastNewestID = nil
        hasGathered = false
        AppLog.shared.info("folder watcher started; scope=\(folderPath) (direct FS watch + \(Int(pollInterval))s poll, Spotlight-independent)")
        beginVnodeWatch()
        beginPoll()
        runScan()  // initial gather, immediately
    }

    public func update(folderPath: String) {
        AppLog.shared.info("watcher re-pointed to \(folderPath)")
        self.folderPath = folderPath
        start()
    }

    public func stop() {
        source?.cancel()  // cancel handler closes the fd
        source = nil
        pollTimer?.cancel()
        pollTimer = nil
        debounceTask?.cancel()
        debounceTask = nil
    }

    // MARK: Watch legs

    private func beginVnodeWatch() {
        let fd = open(folderPath, O_EVTONLY)
        guard fd >= 0 else {
            // Not fatal: the poll leg still catches new screenshots.
            AppLog.shared.warn("folder watcher: open(\(folderPath)) failed (errno \(errno)); poll-only until re-point")
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend, .attrib],
            queue: scanQueue)
        // Must be explicitly @Sendable: otherwise the closure inherits this
        // @MainActor method's isolation, and dispatch invoking it on scanQueue
        // trips a fatal executor assertion. Non-isolated handler hops via Task.
        let onEvent: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in self?.scheduleScan() }
        }
        src.setEventHandler(handler: onEvent)
        src.setCancelHandler { close(fd) }
        source = src
        src.resume()
    }

    private func beginPoll() {
        let timer = DispatchSource.makeTimerSource(queue: scanQueue)
        timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval, leeway: .seconds(1))
        // @Sendable for the same reason as the vnode handler above.
        let onTick: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in self?.runScan() }
        }
        timer.setEventHandler(handler: onTick)
        pollTimer = timer
        timer.resume()
    }

    // MARK: Scan

    /// Debounced scan: collapses a burst of vnode events into one enumeration.
    private func scheduleScan() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.debounce ?? 0.2) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.runScan()
        }
    }

    /// Enumerates the folder off-main, then delivers the result on the main actor.
    private func runScan() {
        let path = folderPath
        let limit = displayLimit
        scanQueue.async { [weak self] in
            let entries = Self.enumerate(path)
            var ordered = screenshots(fromEntries: entries)
            if let limit { ordered = Array(ordered.prefix(limit)) }
            let newest = ordered.first
            Task { @MainActor [weak self] in
                self?.deliver(ordered: ordered, newest: newest, scannedPath: path)
            }
        }
    }

    private func deliver(ordered: [Screenshot], newest: Screenshot?, scannedPath: String) {
        // Drop results from a folder we've since stopped watching.
        guard scannedPath == folderPath else { return }
        onUpdate?(ordered)
        if let newest, newest.id != lastNewestID {
            if hasGathered { onNewScreenshots?([newest]) }
            lastNewestID = newest.id
        }
        hasGathered = true
    }

    /// Reads a directory into raw entries. `nonisolated static` so it runs on the
    /// scan queue. Returns an empty list if the folder can't be read.
    nonisolated private static func enumerate(_ path: String) -> [DirectoryEntry] {
        let keys: [URLResourceKey] = [.nameKey, .isRegularFileKey, .contentModificationDateKey]
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else {
            return []
        }
        return urls.map { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            return DirectoryEntry(
                url: url,
                name: values?.name ?? url.lastPathComponent,
                isRegularFile: values?.isRegularFile ?? true,
                modificationDate: values?.contentModificationDate ?? .distantPast)
        }
    }

    deinit { source?.cancel() }
}

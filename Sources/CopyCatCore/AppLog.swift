import Foundation

/// Severity of a log line.
public enum LogLevel: String, Sendable {
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
}

/// Append-only activity log for the app. Every meaningful action calls
/// `AppLog.shared.info(...)` (or `warn`/`error`) so we have a durable trail of
/// what CopyCat did and when, for debugging.
///
/// File: `~/Library/Application Support/copy-cat/copy-cat.log`, next to
/// `config.json`. Writes are serialized on a background queue so callers (main
/// actor or detector queue) never block on disk IO. The file is bounded: on
/// startup, if it grew past ~1 MB we keep the most recent ~512 KB.
///
/// Concurrency: timestamps are formatted with value-type `Calendar`/
/// `DateComponents` (no shared `DateFormatter`), and every argument crossing
/// into the write queue is `Sendable`, so this is safe under Swift 6 strict
/// concurrency.
public final class AppLog: @unchecked Sendable {
    public static let shared = AppLog()

    private let url: URL
    private let queue = DispatchQueue(label: "com.0x63616c.copy-cat.log", qos: .utility)

    public init(url: URL = AppLog.defaultURL()) {
        self.url = url
        queue.async { Self.trimIfNeeded(url) }
    }

    /// `~/Library/Application Support/copy-cat/copy-cat.log`
    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("copy-cat", isDirectory: true)
            .appendingPathComponent("copy-cat.log", isDirectory: false)
    }

    /// The file the log is written to (for the "Open Logs" action).
    public var fileURL: URL { url }

    public func log(_ message: String, level: LogLevel = .info) {
        let date = Date()
        let url = self.url
        queue.async {
            let line = "\(Self.timestamp(date)) [\(level.rawValue)] \(message)\n"
            Self.append(line, to: url)
        }
    }

    public func info(_ message: String) { log(message, level: .info) }
    public func warn(_ message: String) { log(message, level: .warn) }
    public func error(_ message: String) { log(message, level: .error) }

    // MARK: - File IO (serial queue only)

    private static func append(_ line: String, to url: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            // File doesn't exist yet (or couldn't open) — create it.
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Keep the log bounded: if it exceeds `maxBytes`, rewrite it with the last
    /// `keepBytes`, dropping the leading partial line so the file stays clean.
    private static func trimIfNeeded(_ url: URL, maxBytes: Int = 1_048_576, keepBytes: Int = 524_288) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int, size > maxBytes,
              let data = try? Data(contentsOf: url) else { return }
        let tail = data.suffix(keepBytes)
        if let nl = tail.firstIndex(of: 0x0A) {
            try? Data(tail[tail.index(after: nl)...]).write(to: url, options: .atomic)
        } else {
            try? Data(tail).write(to: url, options: .atomic)
        }
    }

    /// `yyyy-MM-dd HH:mm:ss.SSS` in local time, built from value types only.
    private static func timestamp(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let c = cal.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
        let ms = (c.nanosecond ?? 0) / 1_000_000
        return String(
            format: "%04d-%02d-%02d %02d:%02d:%02d.%03d",
            c.year ?? 0, c.month ?? 0, c.day ?? 0,
            c.hour ?? 0, c.minute ?? 0, c.second ?? 0, ms)
    }
}

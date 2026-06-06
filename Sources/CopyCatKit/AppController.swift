import SwiftUI
import CopyCatCore

@MainActor
public final class AppController: ObservableObject {
    @Published public private(set) var screenshots: [Screenshot] = []
    @Published public private(set) var status: AppStatus = resolveStatus(
        hasAccess: true, savingToDisk: true, screenshotCount: 0)
    @Published public var settings: AppSettings

    /// The tile currently hovered, shown as a floating preview. `nil` = no preview.
    @Published public private(set) var hoveredPreview: Screenshot?

    /// The id of the tile that was just copied, used to flash a "Copied" overlay.
    /// Cleared automatically a moment after the copy.
    @Published public private(set) var justCopiedID: Screenshot.ID?
    private var copyFlashTask: Task<Void, Never>?

    /// Invoked on the main actor whenever `status` is recomputed (badge sync).
    public var onStatusChange: (() -> Void)?
    /// Invoked on the main actor when the hovered tile changes (floating preview).
    public var onHoverChange: ((Screenshot?) -> Void)?
    /// Invoked on the main actor when navigation changes (settings open/close),
    /// so the shell can resize the live popover without a reopen.
    public var onSettingsChange: (() -> Void)?
    /// Invoked on the main actor when a view asks to pick the watch folder. The
    /// AppKit shell owns this so it can pin the popover open across the modal
    /// NSOpenPanel, then resume normal click-outside dismissal.
    public var onChooseFolder: (() -> Void)?

    /// Asks the shell to present the watch-folder picker.
    public func requestChooseFolder() {
        log.info("clicked Choose… (watch-folder picker)")
        onChooseFolder?()
    }

    /// Logged by the shell when the folder picker is dismissed without a choice.
    public func folderPickerCancelled() { log.info("watch-folder picker cancelled") }

    /// Logged by the shell when the menu-bar icon opens/closes the popover.
    public func popoverOpened() { log.info("popover opened") }
    public func popoverClosed() { log.info("popover closed") }

    /// Whether Settings is showing inline inside the popover (replacing the grid).
    /// Settings lives *in* the popover rather than a separate window so it stays
    /// anchored to the menu bar and can't be dragged around.
    @Published public private(set) var showingSettings = false

    private let store: SettingsStore
    private let clipboard: Clipboard
    private let prefs: ScreencapturePreferences
    private let access: FolderAccessing
    private let log = AppLog.shared
    private var detector: ScreenshotDetector?
    /// Last access state we logged, so we only log access transitions, not every poll.
    private var lastLoggedAccess: Bool?
    /// Newest screenshot seen while paused, to back-fill on resume.
    private var pendingBackfill: Screenshot?

    public init(
        store: SettingsStore = SettingsStore(),
        clipboard: Clipboard = NSPasteboardClipboard(),
        prefs: ScreencapturePreferences = SystemScreencapturePreferences(),
        access: FolderAccessing = FolderAccess()
    ) {
        self.store = store
        self.clipboard = clipboard
        self.prefs = prefs
        self.access = access
        self.settings = store.load()
    }

    private var home: String { NSHomeDirectory() }

    /// Resolved folder being watched.
    public var watchFolder: String {
        settings.saveLocationPath ?? prefs.resolvedLocation(home: home)
    }

    /// Starts the live detector. Called by the app shell, never by tests.
    public func start() {
        log.info("app starting (v\(CopyCatCore.version)); watchFolder=\(watchFolder)")
        let bookmark = access.resolveBookmark()
        log.info("bookmark \(bookmark == nil ? "not found (relying on default access)" : "resolved: \(bookmark!.path)")")
        let detector = ScreenshotDetector(folderPath: watchFolder)
        detector.onUpdate = { [weak self] shots in self?.ingest(shots) }
        detector.onNewScreenshots = { [weak self] fresh in self?.handleNew(fresh) }
        self.detector = detector
        detector.start()
        refreshStatus()
    }

    func ingest(_ shots: [Screenshot]) {
        let delta = shots.count - screenshots.count
        screenshots = shots
        log.info("folder update: \(shots.count) screenshots\(delta == 0 ? "" : " (\(delta > 0 ? "+" : "")\(delta))")")
        refreshStatus()
    }

    func handleNew(_ fresh: [Screenshot]) {
        guard let newest = fresh.first else { return }
        let name = newest.url.lastPathComponent
        guard settings.copyOnScreenshot else {
            log.info("new screenshot: \(name) (auto-copy off, not copying)")
            return
        }
        if status.autoCopyPaused {
            pendingBackfill = newest
            log.warn("new screenshot: \(name) (auto-copy paused, queued for backfill)")
        } else {
            clipboard.copyImage(at: newest.url)
            log.info("new screenshot: \(name) → copied to clipboard")
        }
    }

    func refreshStatus() {
        let hasAccess = access.canRead(path: watchFolder)
        if hasAccess != lastLoggedAccess {
            if hasAccess {
                log.info("folder access OK: \(watchFolder)")
            } else {
                log.error("folder access DENIED: \(watchFolder)")
            }
            lastLoggedAccess = hasAccess
        }
        let wasPaused = status.autoCopyPaused
        status = resolveStatus(
            hasAccess: hasAccess,
            savingToDisk: prefs.isSavingToDisk,
            screenshotCount: screenshots.count
        )
        if wasPaused && !status.autoCopyPaused, settings.copyOnScreenshot,
           let backfill = pendingBackfill ?? screenshots.first {
            clipboard.copyImage(at: backfill.url)
            pendingBackfill = nil
            log.info("auto-copy resumed → backfilled \(backfill.url.lastPathComponent)")
        }
        onStatusChange?()
    }

    // MARK: User actions

    public func copy(_ shot: Screenshot) {
        clipboard.copyImage(at: shot.url)
        log.info("manual copy: \(shot.url.lastPathComponent)")
        flashCopied(shot.id)
    }

    /// Briefly marks `id` as just-copied so the grid can show a confirmation.
    private func flashCopied(_ id: Screenshot.ID) {
        justCopiedID = id
        copyFlashTask?.cancel()
        copyFlashTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled else { return }
            self?.justCopiedID = nil
        }
    }

    /// Opens the settings pane beside the grid.
    public func openSettings() {
        log.info("settings opened")
        showingSettings = true
        onSettingsChange?()
    }

    /// Closes the settings pane, returning to the grid alone.
    public func closeSettings() {
        log.info("settings closed (back button)")
        showingSettings = false
        onSettingsChange?()
    }

    /// Toggles the settings pane (gear button).
    public func toggleSettings() {
        log.info("gear button → settings \(showingSettings ? "closing" : "opening")")
        showingSettings.toggle()
        onSettingsChange?()
    }

    /// Resets to the grid view (called when the popover dismisses).
    public func resetNavigation() { showingSettings = false }

    /// Sets the hovered tile and notifies the floating-preview presenter.
    public func setHoveredPreview(_ shot: Screenshot?) {
        guard hoveredPreview != shot else { return }
        hoveredPreview = shot
        if let shot {
            log.info("hover: \(shot.url.lastPathComponent)")
        } else {
            log.info("hover ended")
        }
        onHoverChange?(shot)
    }

    public func updateSettings(_ newSettings: AppSettings) {
        let old = settings
        settings = newSettings
        try? store.save(settings)
        if settings.copyOnScreenshot != old.copyOnScreenshot {
            log.info("setting changed: copyOnScreenshot=\(settings.copyOnScreenshot)")
        }
        if settings.saveLocationPath != old.saveLocationPath {
            log.info("watch folder changed → \(watchFolder)")
            lastLoggedAccess = nil  // re-log access state for the new folder
            detector?.update(folderPath: watchFolder)
        }
        refreshStatus()
    }

    public func enableFileTarget() {
        prefs.enableFileTarget()
        log.info("enabled screencapture file target")
        refreshStatus()
    }

    public func disableThumbnail() {
        prefs.disableThumbnail()
        log.info("disabled screencapture floating thumbnail")
    }

    public func chooseFolder(_ url: URL) {
        access.saveBookmark(for: url)
        log.info("watch folder chosen: \(url.path)")
        var s = settings
        s.saveLocationPath = url.path
        updateSettings(s)
    }

    public func useEscapeHatch() {
        let url = access.escapeHatchFolder()
        log.info("using escape-hatch folder: \(url.path)")
        var s = settings
        s.saveLocationPath = url.path
        updateSettings(s)
    }

    public func openPrivacySettings() {
        log.info("opened Privacy & Security settings")
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")!
        NSWorkspace.shared.open(url)
    }

    /// Opens the activity log file in its default handler (Console on macOS).
    public func openLogs() {
        log.info("opened activity log from settings")
        NSWorkspace.shared.open(log.fileURL)
    }

    public func revealInFinder(_ shot: Screenshot) {
        log.info("reveal in Finder: \(shot.url.lastPathComponent)")
        NSWorkspace.shared.activateFileViewerSelecting([shot.url])
    }

    public func copyPath(_ shot: Screenshot) {
        log.info("copy path: \(shot.url.path)")
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(shot.url.path, forType: .string)
    }
}

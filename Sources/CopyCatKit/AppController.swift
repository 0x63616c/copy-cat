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
    /// Invoked on the main actor when grid-affecting settings change, so the
    /// shell can resize the live popover without a reopen.
    public var onSettingsChange: (() -> Void)?

    /// Whether Settings is showing inline inside the popover (replacing the grid).
    /// Settings lives *in* the popover rather than a separate window so it stays
    /// anchored to the menu bar and can't be dragged around.
    @Published public private(set) var showingSettings = false

    private let store: SettingsStore
    private let clipboard: Clipboard
    private let prefs: ScreencapturePreferences
    private let access: FolderAccessing
    private var detector: ScreenshotDetector?
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
        _ = access.resolveBookmark()
        let detector = ScreenshotDetector(folderPath: watchFolder)
        detector.onUpdate = { [weak self] shots in self?.ingest(shots) }
        detector.onNewScreenshots = { [weak self] fresh in self?.handleNew(fresh) }
        self.detector = detector
        detector.start()
        refreshStatus()
    }

    func ingest(_ shots: [Screenshot]) {
        screenshots = shots
        refreshStatus()
    }

    func handleNew(_ fresh: [Screenshot]) {
        guard settings.copyOnScreenshot, let newest = fresh.first else { return }
        if status.autoCopyPaused {
            pendingBackfill = newest
        } else {
            clipboard.copyImage(at: newest.url)
        }
    }

    func refreshStatus() {
        let hasAccess = access.canRead(path: watchFolder)
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
        }
        onStatusChange?()
    }

    // MARK: User actions

    public func copy(_ shot: Screenshot) {
        clipboard.copyImage(at: shot.url)
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

    /// Shows Settings inline inside the popover.
    public func openSettings() {
        showingSettings = true
        onSettingsChange?()
    }

    /// Returns from Settings to the screenshot grid.
    public func closeSettings() {
        showingSettings = false
        onSettingsChange?()
    }

    /// Resets to the grid view (called when the popover dismisses).
    public func resetNavigation() { showingSettings = false }

    /// Sets the hovered tile and notifies the floating-preview presenter.
    public func setHoveredPreview(_ shot: Screenshot?) {
        guard hoveredPreview != shot else { return }
        hoveredPreview = shot
        onHoverChange?(shot)
    }

    public func updateSettings(_ newSettings: AppSettings) {
        let old = settings
        settings = newSettings.clamped()
        try? store.save(settings)
        if settings.saveLocationPath != old.saveLocationPath {
            detector?.update(folderPath: watchFolder)
        }
        refreshStatus()
        if settings.gridColumns != old.gridColumns || settings.gridRows != old.gridRows {
            onSettingsChange?()
        }
    }

    public func enableFileTarget() { prefs.enableFileTarget(); refreshStatus() }
    public func disableThumbnail() { prefs.disableThumbnail() }

    public func chooseFolder(_ url: URL) {
        access.saveBookmark(for: url)
        var s = settings
        s.saveLocationPath = url.path
        updateSettings(s)
    }

    public func useEscapeHatch() {
        let url = access.escapeHatchFolder()
        var s = settings
        s.saveLocationPath = url.path
        updateSettings(s)
    }

    public func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")!
        NSWorkspace.shared.open(url)
    }

    public func revealInFinder(_ shot: Screenshot) {
        NSWorkspace.shared.activateFileViewerSelecting([shot.url])
    }

    public func copyPath(_ shot: Screenshot) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(shot.url.path, forType: .string)
    }
}

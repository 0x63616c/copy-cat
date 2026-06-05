import AppKit
import SwiftUI
import CopyCatCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let controller = AppController()
    private let previewWC = PreviewWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        updateBadge()

        controller.onStatusChange = { [weak self] in self?.updateBadge() }
        controller.onHoverChange = { [weak self] shot in self?.updatePreview(shot) }
        controller.onSettingsChange = { [weak self] in self?.applyNavigation() }

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = popoverSize()
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView().environmentObject(controller))
    }

    private func updateBadge() {
        guard let button = statusItem?.button else { return }
        // Folder-access warning keeps the SF Symbol triangle. The normal state uses the
        // bundled cat silhouette as a template image (auto dark-in-light / white-in-dark),
        // falling back to the `cat.fill` SF Symbol if the asset is missing (e.g. raw binary).
        if controller.status.content == .noAccess {
            let name = badgeSymbolName(for: controller.status.content)
            button.image = NSImage(systemSymbolName: name, accessibilityDescription: "CopyCat: folder access needed")
            button.image?.isTemplate = true
        } else if let cat = Self.menuBarCatImage() {
            button.image = cat
        } else {
            button.image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "CopyCat")
            button.image?.isTemplate = true
        }
    }

    /// The cat silhouette template glyph for the menu bar, loaded from the app bundle.
    ///
    /// The source PDF carries ~18% of empty margin on every side, which makes the
    /// silhouette render about half its intended size in the bar. We crop that margin
    /// off and redraw the inner region to fill the full 18pt box.
    private static func menuBarCatImage() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "menubar-cat", withExtension: "pdf"),
              let source = NSImage(contentsOf: url) else { return nil }

        let target = NSSize(width: 18, height: 18)
        let inset: CGFloat = 0.18  // trim 18% off each side
        let src = source.size
        let cropRect = NSRect(
            x: src.width * inset,
            y: src.height * inset,
            width: src.width * (1 - 2 * inset),
            height: src.height * (1 - 2 * inset)
        )

        let cropped = NSImage(size: target)
        cropped.lockFocus()
        source.draw(in: NSRect(origin: .zero, size: target),
                    from: cropRect,
                    operation: .sourceOver,
                    fraction: 1.0)
        cropped.unlockFocus()
        cropped.isTemplate = true
        return cropped
    }

    private func updatePreview(_ shot: Screenshot?) {
        if let shot, popover.isShown {
            previewWC.show(shot, anchor: popover.contentViewController?.view.window)
        } else {
            previewWC.hide()
        }
    }

    /// Reacts to a navigation/grid change: resizes the popover to fit the current
    /// view and, while Settings is showing, pins the popover open
    /// (`.applicationDefined`) so the folder picker doesn't dismiss it. Returns to
    /// `.transient` for the grid so outside clicks dismiss as usual.
    private func applyNavigation() {
        popover.behavior = controller.showingSettings ? .applicationDefined : .transient
        guard popover.isShown else { return }
        popover.animates = true
        popover.contentSize = popoverSize()
    }

    private func popoverSize() -> NSSize {
        if controller.showingSettings { return PopoverMetrics.settingsSize }
        let s = PopoverMetrics.size(
            columns: controller.settings.gridColumns,
            rows: controller.settings.gridRows,
            count: controller.screenshots.count,
            banner: controller.status.showNotSavingBanner)
        return NSSize(width: s.width, height: s.height)
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            controller.refreshStatus()
            updateBadge()
            popover.contentSize = popoverSize()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        controller.setHoveredPreview(nil)
        previewWC.hide()
        // Reopen to the grid next time, not stuck in Settings.
        controller.resetNavigation()
    }
}

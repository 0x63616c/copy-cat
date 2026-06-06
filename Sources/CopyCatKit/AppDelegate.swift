import AppKit
import SwiftUI
import CopyCatCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let controller = AppController()
    private let previewWC = PreviewWindowController()
    private var escMonitor: Any?

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
        controller.onChooseFolder = { [weak self] in self?.presentFolderPicker() }

        popover.behavior = .transient
        // Force a dark appearance so the popover's arrow and body share one
        // material. The old approach darkened only the SwiftUI content with a
        // translucent black overlay, which left the AppKit-drawn arrow lighter
        // than the body — a visible seam where they met. Letting the popover
        // chrome own the dark material means the arrow matches by construction.
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.delegate = self
        popover.contentSize = popoverSize()
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView().environmentObject(controller))

        // Esc closes Settings (back to the grid) when it's open, otherwise
        // dismisses the popover entirely. A local monitor reaches the popover's
        // key window where SwiftUI's own key handling is unreliable.
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown, event.keyCode == 53 else { return event }
            if self.controller.showingSettings {
                self.controller.closeSettings()
            } else {
                self.popover.performClose(nil)
            }
            return nil
        }
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

    /// Reacts to a navigation change: resizes the popover to fit the current view.
    /// The popover stays `.transient` whether or not Settings is open, so a click
    /// outside always dismisses it. The folder picker is the one case that would
    /// otherwise dismiss it, so `presentFolderPicker()` pins it across that modal.
    private func applyNavigation() {
        guard popover.isShown else { return }
        if controller.showingSettings {
            // Opening: let AppKit glide the window wider (not an instant snap)
            // while SwiftUI slides the pane into the new space. The grid is
            // pinned left, so the window grows rightward to make room.
            popover.animates = true
            popover.contentSize = popoverSize()
        } else {
            // Closing: let the pane start sliding out, then begin shrinking the
            // window partway through so the two overlap and the collapse feels
            // symmetric with the open (rather than a two-step "slide, then
            // shrink"). The short lead lets the pane's left edge clear the
            // narrower width before the window edge catches up, avoiding a clip.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.paneShrinkLead) { [weak self] in
                guard let self, self.popover.isShown, !self.controller.showingSettings else { return }
                self.popover.animates = true
                self.popover.contentSize = self.popoverSize()
            }
        }
    }

    /// Duration of the settings pane slide; kept in sync with the SwiftUI
    /// `.animation(.smooth(duration:))` in `PopoverRootView`. The SwiftUI side
    /// is the slower, dominant motion (AppKit's window resize is quicker), which
    /// is what makes the open/close feel like an unhurried glide.
    private static let paneSlide: TimeInterval = 0.5

    /// How long the window stays full-width before it starts shrinking on close.
    /// Less than `paneSlide` so the window collapse overlaps the pane slide-out,
    /// mirroring the simultaneous grow+slide on open.
    private static let paneShrinkLead: TimeInterval = 0.22

    private func popoverSize() -> NSSize {
        let s = PopoverMetrics.size(
            columns: AppSettings.gridColumns,
            rows: AppSettings.gridRows,
            count: controller.screenshots.count,
            banner: controller.status.showNotSavingBanner,
            settings: controller.showingSettings)
        return NSSize(width: s.width, height: s.height)
    }

    /// Presents the watch-folder picker. Pins the popover open across the modal
    /// `NSOpenPanel` (which would otherwise resign key and dismiss a transient
    /// popover), then restores normal click-outside dismissal.
    private func presentFolderPicker() {
        let previous = popover.behavior
        popover.behavior = .applicationDefined
        defer { popover.behavior = previous }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            controller.chooseFolder(url)
        } else {
            controller.folderPickerCancelled()
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            controller.popoverOpened()
            controller.refreshStatus()
            updateBadge()
            popover.contentSize = popoverSize()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            // Activate the app and make the popover key so AppKit controls (the
            // Toggle's NSSwitch) render in their active state immediately.
            // Without this the switch first paints as a solid blue block and only
            // corrects once focus changes.
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        controller.popoverClosed()
        controller.setHoveredPreview(nil)
        previewWC.hide()
        // Reopen to the grid next time, not stuck in Settings.
        controller.resetNavigation()
    }
}

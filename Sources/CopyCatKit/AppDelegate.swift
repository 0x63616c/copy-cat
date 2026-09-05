import AppKit
import SwiftUI
import CopyCatCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let controller = AppController()
    private let updates = UpdateManager()
    private let previewWC = PreviewWindowController()
    private var escMonitor: Any?
    private let hotKeys = GlobalHotKeys()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
        updates.start()

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
        controller.onHotKeysChange = { [weak self] in self?.registerHotKeys() }
        registerHotKeys()

        popover.behavior = .transient
        // Let macOS own the material, light/dark appearance, and accessibility.
        popover.appearance = nil
        popover.delegate = self
        popover.contentSize = popoverSize()
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView().environmentObject(controller).environmentObject(updates))

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

    /// The vector template adapts automatically to light and dark menu bars.
    private static func menuBarCatImage() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "menubar-cat", withExtension: "pdf"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 18, height: 18 * image.size.height / image.size.width)
        image.isTemplate = true
        image.accessibilityDescription = "CopyCat"
        return image
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
            popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            popover.contentSize = popoverSize()
        } else {
            // Closing: let the pane start sliding out, then begin shrinking the
            // window partway through so the two overlap and the collapse feels
            // symmetric with the open (rather than a two-step "slide, then
            // shrink"). The short lead lets the pane's left edge clear the
            // narrower width before the window edge catches up, avoiding a clip.
            DispatchQueue.main.asyncAfter(deadline: .now() + (NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : Self.paneShrinkLead)) { [weak self] in
                guard let self, self.popover.isShown, !self.controller.showingSettings else { return }
                self.popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                self.popover.contentSize = self.popoverSize()
            }
        }
    }

    /// A short overlap with the SwiftUI pane transition prevents edge clipping.
    private static let paneShrinkLead: TimeInterval = 0.12

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

    /// (Re)registers the global hotkeys from the current settings. The open
    /// shortcut toggles the popover; the copy shortcut copies the newest shot.
    private func registerHotKeys() {
        hotKeys.reload(
            open: controller.settings.openMenuShortcut,
            openAction: { [weak self] in self?.togglePopoverFromHotKey() },
            copyLast: controller.settings.copyLastShortcut,
            copyAction: { [weak self] in self?.copyLastFromHotKey() })
    }

    /// Copy-last hotkey: open the menu (if closed) so the grid is visible, then
    /// copy the newest shot — the flashed "Copied" overlay confirms it landed.
    private func copyLastFromHotKey() {
        guard let button = statusItem?.button else { return }
        if !popover.isShown {
            AppLog.shared.info("copy-last hotkey → opening popover to show confirmation")
            togglePopover(button)
        }
        controller.copyLastScreenshot()
    }

    /// Opens (or closes) the popover in response to the global open hotkey.
    private func togglePopoverFromHotKey() {
        guard let button = statusItem?.button else { return }
        AppLog.shared.info("open-menu hotkey → \(popover.isShown ? "closing" : "opening") popover")
        togglePopover(button)
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

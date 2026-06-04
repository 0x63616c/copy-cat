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

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = popoverSize()
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView().environmentObject(controller))
    }

    private func updateBadge() {
        guard let button = statusItem?.button else { return }
        let name = badgeSymbolName(for: controller.status.content)
        button.image = NSImage(systemSymbolName: name, accessibilityDescription: "copy-cat")
        button.image?.isTemplate = true
    }

    private func updatePreview(_ shot: Screenshot?) {
        if let shot, popover.isShown {
            previewWC.show(shot, anchor: popover.contentViewController?.view.window)
        } else {
            previewWC.hide()
        }
    }

    private func popoverSize() -> NSSize {
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
    }
}

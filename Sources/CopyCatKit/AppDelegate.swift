import AppKit
import SwiftUI
import CopyCatCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let controller = AppController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        updateBadge()

        // Keep the menu bar badge in sync with access state.
        controller.onStatusChange = { [weak self] in self?.updateBadge() }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 720, height: 460)
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView().environmentObject(controller))
    }

    private func updateBadge() {
        guard let button = statusItem?.button else { return }
        let name = badgeSymbolName(for: controller.status.content)
        button.image = NSImage(systemSymbolName: name, accessibilityDescription: "copy-cat")
        button.image?.isTemplate = true
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            controller.refreshStatus()
            updateBadge()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

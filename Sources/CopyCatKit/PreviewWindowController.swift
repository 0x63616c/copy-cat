import AppKit
import SwiftUI
import CopyCatCore

/// Manages a borderless, non-activating floating panel that shows the large
/// preview tooltip to the left of the main popover on hover.
@MainActor
final class PreviewWindowController {
    private let panel: NSPanel
    private let hosting: NSHostingController<FloatingPreview>

    init() {
        hosting = NSHostingController(rootView: FloatingPreview(screenshot: nil))
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false                 // shadow is drawn by the SwiftUI card
        panel.level = .popUpMenu
        panel.ignoresMouseEvents = true         // never steal the hover
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = hosting
    }

    /// Show the preview for `shot`, positioned to the left of `anchor` (the
    /// popover window). Flips to the right if there's no room on the left.
    func show(_ shot: Screenshot, anchor: NSWindow?) {
        hosting.rootView = FloatingPreview(screenshot: shot)
        hosting.view.layoutSubtreeIfNeeded()
        let size = hosting.view.fittingSize
        panel.setContentSize(size)

        guard let anchor else { panel.orderFront(nil); return }
        let frame = anchor.frame
        let gap: CGFloat = 8
        var x = frame.minX - size.width - gap
        if x < (anchor.screen?.visibleFrame.minX ?? 0) {
            x = frame.maxX + gap // not enough room on the left -> flip right
        }
        let y = frame.maxY - size.height // align tops
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }
}

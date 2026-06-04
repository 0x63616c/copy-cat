import AppKit

@MainActor private var sharedDelegate: AppDelegate?

/// Boots the menu bar app. Retains the delegate for the process lifetime.
@MainActor
public func runApp() {
    let delegate = AppDelegate()
    sharedDelegate = delegate
    let app = NSApplication.shared
    app.delegate = delegate
    app.setActivationPolicy(.accessory) // no Dock icon (belt-and-suspenders for LSUIElement)
    app.run()
}

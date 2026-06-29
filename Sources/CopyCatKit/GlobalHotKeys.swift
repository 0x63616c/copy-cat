import AppKit
import Carbon.HIToolbox
import CopyCatCore

/// Registers system-wide hotkeys via Carbon's `RegisterEventHotKey`.
///
/// Carbon hotkeys fire regardless of which app is focused and — unlike
/// `NSEvent.addGlobalMonitorForEvents` — do **not** require the Accessibility
/// permission, so the utility works the moment it launches with no extra prompt.
/// Events are delivered on the main thread, which is why the C handler can safely
/// hop back onto the main actor.
@MainActor
final class GlobalHotKeys {
    private struct Registration {
        let ref: EventHotKeyRef
        let action: () -> Void
    }

    /// hotkey id → its registration. Ids are assigned sequentially per process.
    private var registrations: [UInt32: Registration] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?
    private let signature = OSType(0x43505943) // 'CPYC'
    private let log = AppLog.shared

    /// Replaces all current registrations with the two given shortcuts. Safe to
    /// call repeatedly (e.g. after the user edits a shortcut in Settings).
    func reload(
        open: HotKey, openAction: @escaping () -> Void,
        copyLast: HotKey, copyAction: @escaping () -> Void
    ) {
        unregisterAll()
        installHandlerIfNeeded()
        register(open, action: openAction, label: "open menu")
        register(copyLast, action: copyAction, label: "copy last")
    }

    // MARK: Private

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID)
                let id = hkID.id
                // Carbon delivers hotkey events on the main thread.
                MainActor.assumeIsolated {
                    Unmanaged<GlobalHotKeys>.fromOpaque(userData)
                        .takeUnretainedValue()
                        .handle(id: id)
                }
                return noErr
            },
            1, &spec, selfPtr, &eventHandler)
    }

    private func handle(id: UInt32) {
        registrations[id]?.action()
    }

    private func register(_ s: HotKey, action: @escaping () -> Void, label: String) {
        guard s.hasModifier else {
            log.warn("hotkey '\(label)' = \(s.displayString) has no modifier; not registering")
            return
        }
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(
            UInt32(s.keyCode),
            carbonModifiers(s),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref)
        if status == noErr, let ref {
            registrations[id] = Registration(ref: ref, action: action)
            log.info("registered hotkey '\(label)' = \(s.displayString)")
        } else {
            log.error("failed to register hotkey '\(label)' = \(s.displayString) (OSStatus \(status); likely taken by another app)")
        }
    }

    private func unregisterAll() {
        for reg in registrations.values {
            UnregisterEventHotKey(reg.ref)
        }
        registrations.removeAll()
    }

    private func carbonModifiers(_ s: HotKey) -> UInt32 {
        var m: UInt32 = 0
        if s.command { m |= UInt32(cmdKey) }
        if s.shift { m |= UInt32(shiftKey) }
        if s.option { m |= UInt32(optionKey) }
        if s.control { m |= UInt32(controlKey) }
        return m
    }
}

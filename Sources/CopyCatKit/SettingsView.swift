import SwiftUI
import AppKit
import CopyCatCore

/// Settings content, shown inline inside the popover (see `PopoverRootView`).
/// Every control applies live through `AppController` the moment it changes —
/// there is no Save step. The popover header provides the title and a back
/// button, so this view is just the form. Styled after macOS 26 System
/// Settings: grouped cards, section footers for explanation, SF Symbols on rows.
struct SettingsView: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        Form {
            captureSection
            shortcutsSection
            librarySection
            diagnosticsSection
        }
        .formStyle(.grouped)
        // Drop the grouped form's opaque background so the popover's dark
        // material shows through, matching the grid column beside it. The
        // section "cards" keep their own subtle fills.
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Sections

    private var captureSection: some View {
        Section {
            Toggle(isOn: setting(\.copyOnScreenshot)) {
                Label("Copy on screenshot", systemImage: "camera.viewfinder")
            }
            .toggleStyle(PillToggleStyle())
        } header: {
            Text("Capture")
        } footer: {
            Text("When a new screenshot appears, copy it to the clipboard automatically.")
        }
    }

    private var shortcutsSection: some View {
        Section {
            ShortcutRecorderView(
                title: "Open CopyCat",
                systemImage: "menubar.arrow.up.rectangle",
                shortcut: setting(\.openMenuShortcut))
            ShortcutRecorderView(
                title: "Copy last screenshot",
                systemImage: "doc.on.clipboard",
                shortcut: setting(\.copyLastShortcut))
        } header: {
            Text("Shortcuts")
        } footer: {
            Text("Global hotkeys that work from any app. Click a shortcut, then press the new keys (must include a modifier). ⎋ cancels.")
        }
    }

    private var librarySection: some View {
        Section {
            // Button rides the label row (always has room); the path gets its
            // own full-width line below, middle-truncated so a long path never
            // wraps and breaks the row.
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Label("Watch folder", systemImage: "folder")
                    Spacer(minLength: 8)
                    Button("Choose…") { controller.requestChooseFolder() }
                }
                Text(controller.settings.saveLocationPath ?? "macOS default")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } header: {
            Text("Library")
        } footer: {
            Text("The folder CopyCat watches for new screenshots.")
        }
    }

    private var diagnosticsSection: some View {
        Section {
            LabeledContent {
                Button("Open Logs") { controller.openLogs() }
            } label: {
                Label("Activity log", systemImage: "doc.text.magnifyingglass")
            }
        } header: {
            Text("Diagnostics")
        } footer: {
            Text("CopyCat records what it does to a log file. Open it to see recent activity.")
        }
    }

    // MARK: Live binding

    /// A binding into `AppController.settings` that persists and applies the
    /// change immediately (no Save button), so the popover resizes live.
    private func setting<T: Equatable>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { controller.settings[keyPath: keyPath] },
            set: { newValue in
                var next = controller.settings
                next[keyPath: keyPath] = newValue
                controller.updateSettings(next)
            })
    }
}

/// A row that displays a `HotKey` and, on click, records a new one
/// from the next modified keypress. While recording it installs a local keyDown
/// monitor on the popover's key window; the first key with a modifier wins, ⎋
/// cancels. Stays pure data — it never touches Carbon (that's `GlobalHotKeys`).
struct ShortcutRecorderView: View {
    let title: String
    let systemImage: String
    @Binding var shortcut: HotKey

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Label(title, systemImage: systemImage)
            Spacer(minLength: 8)
            Button(action: toggle) {
                Text(isRecording ? "Type shortcut…" : shortcut.displayString)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(isRecording ? Color.accentColor : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        isRecording ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isRecording ? Color.accentColor : .clear, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Click, then press a new key combination")
        }
        .onDisappear { stop() }
    }

    private func toggle() {
        if isRecording { stop() } else { start() }
    }

    private func start() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags
            let candidate = HotKey(
                keyCode: event.keyCode,
                command: flags.contains(.command),
                control: flags.contains(.control),
                option: flags.contains(.option),
                shift: flags.contains(.shift))
            // ⎋ with no modifiers cancels recording.
            if event.keyCode == 53 && !candidate.hasModifier {
                stop()
                return nil
            }
            // Require at least one modifier; otherwise keep listening (a bare key
            // would be a poor global hotkey and would hijack normal typing).
            guard candidate.hasModifier else { return nil }
            shortcut = candidate
            stop()
            return nil  // consume so the key doesn't leak to the popover
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}

/// A pure-SwiftUI switch. The system `.switch` Toggle renders as a solid blue
/// block inside this popover's `NSHostingView` until focus changes — an AppKit
/// `NSSwitch` layout bug that survives activating/keying the window. Drawing the
/// control ourselves sidesteps it entirely and animates more smoothly.
struct PillToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
            Spacer(minLength: 0)
            Button {
                configuration.isOn.toggle()
            } label: {
                ZStack {
                    Capsule()
                        .fill(configuration.isOn ? Color.accentColor : Color.primary.opacity(0.22))
                    Circle()
                        .fill(.white)
                        .frame(width: 18, height: 18)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                        .offset(x: configuration.isOn ? 8 : -8)
                }
                .frame(width: 38, height: 22)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isOn)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(configuration.isOn ? [.isButton, .isSelected] : .isButton)
        }
    }
}

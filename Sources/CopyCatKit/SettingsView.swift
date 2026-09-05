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
    @EnvironmentObject var updates: UpdateManager
    @ObservedObject var loginItem: LoginItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                generalSection
                updatesSection
                shortcutsSection
                librarySection
                diagnosticsSection
            }
            .padding(14)
        }
        .environment(\.font, .system(size: 13))
        // Drop the grouped form's opaque background so the popover's
        // material shows through, matching the grid column beside it. The
        // section "cards" keep their own subtle fills.
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loginItem.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItem.refresh()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { aboutFooter }
    }

    private func section<Content: View>(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10, content: content)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.separator, lineWidth: 0.5))
            if let footer { Text(footer).font(.system(size: 10)).foregroundStyle(.secondary) }
        }
        .controlSize(.small)
    }

    // MARK: Sections

    private var updatesSection: some View {
        section("Updates") {
            HStack {
                Label("Software Update", systemImage: "arrow.down.circle")
                Spacer()
                Button("Check for Updates…") { updates.checkForUpdates() }
                    .controlSize(.small).disabled(!updates.canCheck)
            }
            Toggle(isOn: Binding(get: { updates.automaticallyChecks }, set: { updates.setAutomaticallyChecks($0) })) {
                Label("Check for updates automatically", systemImage: "arrow.triangle.2.circlepath")
            }
            .toggleStyle(PillToggleStyle())
            .disabled(!updates.isAvailable)
            Toggle(isOn: Binding(get: { updates.automaticallyInstalls }, set: { updates.setAutomaticallyInstalls($0) })) {
                Label("Install updates automatically", systemImage: "arrow.down.circle")
            }
            .toggleStyle(PillToggleStyle())
            .disabled(!updates.isAvailable || !updates.automaticallyChecks)
            if let error = updates.error {
                Text(error).font(.callout).foregroundStyle(.red)
            }
        }
    }

    private var generalSection: some View {
        section("General") {
            Toggle(isOn: Binding(get: { loginItem.isOn }, set: { loginItem.setEnabled($0) })) {
                Label("Open at Login", systemImage: "power")
            }
            .toggleStyle(PillToggleStyle())
            Toggle(isOn: setting(\.copyOnScreenshot)) {
                Label("Copy on screenshot", systemImage: "camera.viewfinder")
            }
            .toggleStyle(PillToggleStyle())
            if loginItem.status == .requiresApproval {
                Text("Allow CopyCat in Login Items to finish turning this on.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Open Login Items…") { loginItem.openSystemSettings() }
            }
            if loginItem.status == .notFound {
                Text("Move CopyCat to Applications and open it there to enable login startup.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if let error = loginItem.error {
                Text(error).font(.callout).foregroundStyle(.red)
                Button("Open Login Items…") { loginItem.openSystemSettings() }
            }
        }
    }

    private var aboutFooter: some View {
        HStack(spacing: 12) {
            Text("CopyCat \(CopyCatCore.installedVersion)\(CopyCatCore.build.map { " (\($0))" } ?? " · Development")")
                .font(.caption).textSelection(.enabled)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit CopyCat") { NSApplication.shared.terminate(nil) }
                .controlSize(.small)
        }
        .padding(.horizontal, 18)
        .frame(height: PopoverMetrics.footerHeight)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var shortcutsSection: some View {
        section("Shortcuts") {
            ShortcutRecorderView(
                title: "Open CopyCat",
                systemImage: "menubar.arrow.up.rectangle",
                shortcut: setting(\.openMenuShortcut))
            ShortcutRecorderView(
                title: "Copy last screenshot",
                systemImage: "doc.on.clipboard",
                shortcut: setting(\.copyLastShortcut))
        }
    }

    private var librarySection: some View {
        section("Library") {
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
        }
    }

    private var diagnosticsSection: some View {
        section("Diagnostics") {
            HStack {
                Label("Activity log", systemImage: "doc.text.magnifyingglass")
                Spacer(minLength: 8)
                Button("Open Logs") { controller.openLogs() }
            }
        }
    }

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 12) {
                configuration.label
                Spacer(minLength: 0)
                ZStack {
                    Capsule().fill(configuration.isOn ? Color.accentColor : Color.primary.opacity(0.22))
                    Circle().fill(.white)
                        .frame(width: 18, height: 18)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                        .offset(x: configuration.isOn ? 8 : -8)
                }
                .frame(width: 38, height: 22)
                .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: configuration.isOn)
                .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAddTraits(configuration.isOn ? [.isSelected] : [])
    }
}

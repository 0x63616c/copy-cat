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

    private var librarySection: some View {
        Section {
            LabeledContent {
                HStack(spacing: 8) {
                    Text(controller.settings.saveLocationPath ?? "macOS default")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Choose…") { controller.requestChooseFolder() }
                }
            } label: {
                Label("Watch folder", systemImage: "folder")
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

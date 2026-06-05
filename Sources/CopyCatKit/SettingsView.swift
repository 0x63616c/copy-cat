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

    private let range = AppSettings.minDimension...AppSettings.maxDimension

    var body: some View {
        Form {
            captureSection
            librarySection
            gridSection
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Sections

    private var captureSection: some View {
        Section {
            Toggle(isOn: setting(\.copyOnScreenshot)) {
                Label("Copy on screenshot", systemImage: "camera.viewfinder")
            }
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
                    Button("Choose…") { pickFolder() }
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

    private var gridSection: some View {
        Section {
            dimensionRow(
                title: "Columns",
                symbol: "rectangle.split.3x1",
                binding: setting(\.gridColumns))
            dimensionRow(
                title: "Rows visible",
                symbol: "rectangle.split.1x2",
                binding: setting(\.gridRows))
            gridPreview
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        } header: {
            Text("Grid")
        } footer: {
            Text("**Rows visible** is how many rows of recent screenshots fit before the grid scrolls. Older shots stay reachable by scrolling. The popover resizes as you change these (\(range.lowerBound)–\(range.upperBound)).")
        }
    }

    /// One stepper row with a live monospaced value and SF Symbol.
    private func dimensionRow(title: String, symbol: String, binding: Binding<Int>) -> some View {
        LabeledContent {
            HStack(spacing: 12) {
                Text("\(binding.wrappedValue)")
                    .font(.body.weight(.semibold).monospacedDigit())
                    .frame(minWidth: 18, alignment: .trailing)
                    .contentTransition(.numericText())
                Stepper(title, value: binding, in: range)
                    .labelsHidden()
            }
        } label: {
            Label(title, systemImage: symbol)
        }
    }

    /// A miniature live mock of the grid showing the chosen columns × rows.
    private var gridPreview: some View {
        let cols = controller.settings.gridColumns
        let rows = controller.settings.gridRows
        let cell: CGFloat = 14
        let gap: CGFloat = 4
        return VStack(spacing: gap) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: gap) {
                    ForEach(0..<cols, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.accentColor.opacity(0.22))
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04)))
        .animation(.snappy(duration: 0.2), value: cols)
        .animation(.snappy(duration: 0.2), value: rows)
        .accessibilityLabel("Preview: \(cols) columns by \(rows) rows")
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

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            controller.chooseFolder(url)
        }
    }
}

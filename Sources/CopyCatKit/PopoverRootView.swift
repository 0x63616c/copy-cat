import SwiftUI
import AppKit
import CopyCatCore

struct PopoverRootView: View {
    @EnvironmentObject var controller: AppController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var loginItem: LoginItem

    init(loginItem: LoginItem = LoginItem()) {
        _loginItem = StateObject(wrappedValue: loginItem)
    }

    var body: some View {
        HStack(spacing: 0) {
            gridColumn
            if controller.showingSettings {
                Divider()
                settingsPane
                    .frame(width: PopoverMetrics.settingsPaneWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        // Native type across the whole popover: default-font Text/labels/controls
        // inherit this; views with explicit fonts use `Font.cc(...)` directly.
        .environment(\.font, .cc(Typo.body))
        .frame(maxHeight: .infinity, alignment: .top)
        // The popover owns the system material,
        // so arrow and body match. No content-level overlay (which caused the
        // seam against the arrow).
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: controller.showingSettings)
    }

    /// Left side: header + screenshot grid (or empty / no-access state). Fixed to
    /// the natural 4-column width so opening Settings doesn't reflow the grid —
    /// the pane slides into the new space instead of the grid stretching first.
    private var gridColumn: some View {
        VStack(spacing: 0) {
            gridHeader
            if controller.status.showNotSavingBanner {
                NotSavingBanner(
                    onEnable: { controller.enableFileTarget() },
                    onDisableThumbnail: { controller.disableThumbnail() })
            }
            content
            libraryFooter
        }
        .frame(width: PopoverMetrics.minWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var libraryFooter: some View {
        HStack(spacing: 10) {
            Label(copyStatus, systemImage: controller.status.content == .noAccess || controller.status.showNotSavingBanner ? "exclamationmark.circle" : "doc.on.clipboard")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Copy Latest") { controller.copyLastScreenshot() }
                .controlSize(.small)
                .disabled(controller.screenshots.isEmpty)
        }
        .padding(.horizontal, 16)
        .frame(height: PopoverMetrics.footerHeight)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var copyStatus: String {
        if controller.status.content == .noAccess { return "Folder access needed" }
        if controller.status.showNotSavingBanner { return "Save screenshots to files" }
        return controller.settings.copyOnScreenshot ? "Automatic copying on" : "Automatic copying off"
    }

    private var gridHeader: some View {
        headerBar {
            Text("Screenshots").font(.system(size: 15, weight: .semibold))
            if controller.screenshots.count > 0 {
                Text("\(controller.screenshots.count)")
                    .font(.cc(Typo.subheadline, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer()
            if !controller.showingSettings {
                circleButton("gearshape", help: "Settings") { controller.openSettings() }
            }
        }
    }

    /// One popover header row: a leading title (+ trailing control), pinned to a
    /// fixed height so the grid and settings titles line up exactly. Without the
    /// fixed height each header sizes to its own content (the grid header loses
    /// the gear button while Settings is open), which shifts the titles apart.
    private func headerBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8) { content() }
            .frame(height: PopoverMetrics.headerRow)
            .padding(.horizontal, 16)
            .padding(.top, 11)
            .padding(.bottom, 9)
    }

    /// A circular, secondary-tinted icon button used in both header bars.
    private func circleButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .imageScale(.medium)
                .foregroundStyle(.secondary)
                .padding(9)
                .modifier(GlassSurface(cornerRadius: 24, interactive: true))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    /// Right side: the settings pane that slides in, with its own close button.
    private var settingsPane: some View {
        VStack(spacing: 0) {
            headerBar {
                Text("Settings").font(.system(size: 15, weight: .semibold))
                Spacer()
                circleButton("xmark", help: "Close settings") { controller.closeSettings() }
            }
            SettingsView(loginItem: loginItem)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private var content: some View {
        switch controller.status.content {
        case .noAccess:
            NoAccessView(
                onChooseFolder: { chooseFolder() },
                onUseEscapeHatch: { controller.useEscapeHatch() },
                onOpenSettings: { controller.openPrivacySettings() })
        case .empty:
            EmptyStateView()
        case .normal:
            TimelineView(.periodic(from: .now, by: 60)) { context in
            GridView(
                screenshots: controller.screenshots,
                columns: AppSettings.gridColumns,
                justCopiedID: controller.justCopiedID,
                now: context.date,
                onHover: { controller.setHoveredPreview($0) },
                onClick: { controller.copy($0) },
                onReveal: { controller.revealInFinder($0) },
                onCopyPath: { controller.copyPath($0) })
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func chooseFolder() {
        controller.requestChooseFolder()
    }
}

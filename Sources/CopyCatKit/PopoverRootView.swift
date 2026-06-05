import SwiftUI
import AppKit
import CopyCatCore

struct PopoverRootView: View {
    @EnvironmentObject var controller: AppController

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
        // +20% type across the whole popover: default-font Text/labels/controls
        // inherit this; views with explicit fonts use `Font.cc(...)` directly.
        .environment(\.font, .cc(Typo.body))
        .frame(maxHeight: .infinity, alignment: .top)
        // The popover appearance (set on NSPopover) owns the dark material now,
        // so arrow and body match. No content-level overlay (which caused the
        // seam against the arrow).
        .animation(.smooth(duration: 0.5), value: controller.showingSettings)
        // Clear the floating preview if the cursor leaves the popover entirely.
        .onHover { inside in if !inside { controller.setHoveredPreview(nil) } }
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
        }
        .frame(width: PopoverMetrics.minWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var gridHeader: some View {
        HStack(spacing: 8) {
            Text("All Screenshots").font(.cc(Typo.headline, weight: .bold))
            if controller.screenshots.count > 0 {
                Text("\(controller.screenshots.count)")
                    .font(.cc(Typo.subheadline, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                    .contentTransition(.numericText())
            }
            Spacer()
            if !controller.showingSettings {
                Button { controller.openSettings() } label: {
                    Image(systemName: "gearshape")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                        .padding(9)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    /// Right side: the settings pane that slides in, with its own close button.
    private var settingsPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Settings").font(.cc(Typo.headline, weight: .bold))
                Spacer()
                Button { controller.closeSettings() } label: {
                    Image(systemName: "xmark")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                        .padding(9)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Close settings")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            SettingsView()
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
            GridView(
                screenshots: controller.screenshots,
                columns: AppSettings.gridColumns,
                justCopiedID: controller.justCopiedID,
                onHover: { controller.setHoveredPreview($0) },
                onClick: { controller.copy($0) },
                onReveal: { controller.revealInFinder($0) },
                onCopyPath: { controller.copyPath($0) })
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func chooseFolder() {
        controller.requestChooseFolder()
    }
}

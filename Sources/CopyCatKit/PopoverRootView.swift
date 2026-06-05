import SwiftUI
import AppKit
import CopyCatCore

struct PopoverRootView: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        VStack(spacing: 0) {
            header
            if controller.showingSettings {
                SettingsView()
            } else {
                if controller.status.showNotSavingBanner {
                    NotSavingBanner(
                        onEnable: { controller.enableFileTarget() },
                        onDisableThumbnail: { controller.disableThumbnail() })
                }
                content
            }
        }
        // Darken the popover's default material so the grid reads on a deeper,
        // charcoal background instead of the lighter system gray.
        .background(Color.black.opacity(0.28))
        // Clear the floating preview if the cursor leaves the popover entirely.
        .onHover { inside in if !inside { controller.setHoveredPreview(nil) } }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if controller.showingSettings {
                Button { controller.closeSettings() } label: {
                    Image(systemName: "chevron.backward")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
                .help("Back")
                Text("Settings").font(.headline)
                Spacer()
            } else {
                Text("All Screenshots").font(.system(size: 13, weight: .bold))
                Spacer()
                Button { controller.openSettings() } label: {
                    Image(systemName: "gearshape")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
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
                columns: controller.settings.gridColumns,
                justCopiedID: controller.justCopiedID,
                onHover: { controller.setHoveredPreview($0) },
                onClick: { controller.copy($0) },
                onReveal: { controller.revealInFinder($0) },
                onCopyPath: { controller.copyPath($0) })
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            controller.chooseFolder(url)
        }
    }
}

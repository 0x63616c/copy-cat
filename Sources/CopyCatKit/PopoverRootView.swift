import SwiftUI
import AppKit
import CopyCatCore

struct PopoverRootView: View {
    @EnvironmentObject var controller: AppController
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if controller.status.showNotSavingBanner {
                NotSavingBanner(
                    onEnable: { controller.enableFileTarget() },
                    onDisableThumbnail: { controller.disableThumbnail() })
            }
            content
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings).environmentObject(controller)
        }
        // Clear the floating preview if the cursor leaves the popover entirely.
        .onHover { inside in if !inside { controller.setHoveredPreview(nil) } }
    }

    private var header: some View {
        HStack {
            Text("copy-cat").font(.headline)
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .help("Settings")
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

import SwiftUI
import AppKit
import CopyCatCore

struct PopoverRootView: View {
    @EnvironmentObject var controller: AppController
    @State private var hovered: Screenshot?
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if controller.status.showNotSavingBanner {
                NotSavingBanner(
                    onEnable: { controller.enableFileTarget() },
                    onDisableThumbnail: { controller.disableThumbnail() })
            }
            content
        }
        .frame(width: 720, height: 460)
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings).environmentObject(controller)
        }
    }

    private var header: some View {
        HStack {
            Text("copy-cat").font(.headline)
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
            }.buttonStyle(.borderless)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
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
            HStack(spacing: 0) {
                PreviewPane(
                    screenshot: previewTarget(hovered: hovered, newest: controller.screenshots.first),
                    onReveal: { controller.revealInFinder($0) },
                    onCopyPath: { controller.copyPath($0) },
                    onCopyImage: { controller.copy($0) })
                Divider()
                GridView(
                    screenshots: controller.screenshots,
                    columns: controller.settings.gridColumns,
                    maxRows: controller.settings.gridRows,
                    tileSize: 84, spacing: 8,
                    onHover: { hovered = $0 },
                    onClick: { controller.copy($0) })
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
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

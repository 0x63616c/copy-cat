import SwiftUI
import AppKit
import CopyCatCore

struct SettingsView: View {
    @EnvironmentObject var controller: AppController
    @Binding var isPresented: Bool

    @State private var draft: AppSettings = .defaults

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings").font(.headline)

            Toggle("Copy on screenshot", isOn: $draft.copyOnScreenshot)

            HStack {
                Text("Save location")
                Spacer()
                Text(draft.saveLocationPath ?? "macOS default")
                    .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Button("Choose…") { pickFolder() }
            }

            Stepper("Columns: \(draft.gridColumns)", value: $draft.gridColumns, in: 1...8)
            Stepper("Rows: \(draft.gridRows)", value: $draft.gridRows, in: 1...12)

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Save") {
                    controller.updateSettings(draft)
                    isPresented = false
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear { draft = controller.settings }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            controller.chooseFolder(url)
            draft.saveLocationPath = url.path
        }
    }
}

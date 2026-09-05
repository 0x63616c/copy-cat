import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle").font(.largeTitle).foregroundStyle(.secondary)
            Text("No screenshots yet.").font(.cc(Typo.headline, weight: .semibold))
            Text("Press ⌘⇧3 or ⌘⇧4 to take one.").font(.cc(Typo.subheadline)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NotSavingBanner: View {
    let onEnable: () -> Void
    let onDisableThumbnail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Screenshots aren’t being saved to files.", systemImage: "exclamationmark.triangle")
                .font(.cc(Typo.callout))
            HStack {
                Button("Enable", action: onEnable).buttonStyle(.borderedProminent).controlSize(.small)
                Button("Hide thumbnail", action: onDisableThumbnail).buttonStyle(.bordered).controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .padding([.horizontal, .top], 10)
    }
}

struct NoAccessView: View {
    let onChooseFolder: () -> Void
    let onUseEscapeHatch: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield").font(.largeTitle).foregroundStyle(.secondary)
            Text("Can't see your screenshots").font(.cc(Typo.headline, weight: .semibold))
            Text("CopyCat needs permission to read your screenshot folder.")
                .font(.cc(Typo.subheadline)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            VStack(spacing: 8) {
                Button("Choose folder…", action: onChooseFolder).buttonStyle(.borderedProminent)
                Button("Use a folder that needs no permission", action: onUseEscapeHatch).buttonStyle(.bordered)
                Button("Open System Settings", action: onOpenSettings).buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

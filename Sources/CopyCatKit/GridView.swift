import SwiftUI
import AppKit
import CopyCatCore

/// Forces the enclosing `NSScrollView` to overlay scrollers (floating over the
/// content, auto-hiding) instead of the legacy gutter scrollers the system shows
/// when "Show scroll bars" is set to "Always". Scoped to this scroll view only.
private struct OverlayScrollers: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = nsView.enclosingScrollView else { return }
            scrollView.scrollerStyle = .overlay
            scrollView.autohidesScrollers = true
            scrollView.verticalScroller?.controlSize = .small
        }
    }
}

struct GridView: View {
    let screenshots: [Screenshot]
    let columns: Int
    var justCopiedID: Screenshot.ID?
    var now: Date = Date()
    let onHover: (Screenshot?) -> Void
    let onClick: (Screenshot) -> Void
    let onReveal: (Screenshot) -> Void
    let onCopyPath: (Screenshot) -> Void

    @State private var hoveredID: Screenshot.ID?
    @FocusState private var focusedID: Screenshot.ID?
    private var previewID: Screenshot.ID? { hoveredID ?? focusedID }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(PopoverMetrics.tile), spacing: PopoverMetrics.gap, alignment: .topLeading),
            count: max(1, columns)
        )
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: gridColumns, alignment: .center, spacing: PopoverMetrics.gap) {
                ForEach(screenshots) { shot in
                    GridTile(
                        shot: shot,
                        copied: justCopiedID == shot.id,
                        focused: focusedID == shot.id,
                        age: compactRelativeAge(from: shot.captureDate, now: now),
                        onHover: { hovered in
                            if hovered != nil { hoveredID = shot.id }
                            else if hoveredID == shot.id { hoveredID = nil }
                        },
                        onClick: onClick,
                        onReveal: onReveal,
                        onCopyPath: onCopyPath)
                        .focused($focusedID, equals: shot.id)
                }
            }
            .padding(PopoverMetrics.gap)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(OverlayScrollers())
        }
        .onHover { inside in if !inside { hoveredID = nil } }
        .onChange(of: previewID) { _, id in onHover(screenshots.first { $0.id == id }) }
        .onDisappear { hoveredID = nil; focusedID = nil; onHover(nil) }
        .onReceive(NotificationCenter.default.publisher(for: NSPopover.didCloseNotification)) { _ in
            hoveredID = nil; focusedID = nil; onHover(nil)
        }
        // Partial top/bottom rows dissolve instead of being hard-clipped, so the
        // edge reads as "scroll for more" rather than a rendering glitch. The
        // trailing strip is held fully opaque so the overlay scroller (which the
        // mask would otherwise fade at its top/bottom ends, making it look
        // recessed/behind the content) stays crisp and on top.
        .mask(
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: PopoverMetrics.gap)
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: PopoverMetrics.gap)
                }
                Rectangle().frame(width: 16) // scroller lane, never faded
            }
        )
    }
}

/// Image-first card with persistent capture age and equivalent pointer/keyboard feedback.
private struct GridTile: View {
    let shot: Screenshot
    let copied: Bool
    let focused: Bool
    let age: String
    let onHover: (Screenshot?) -> Void
    let onClick: (Screenshot) -> Void
    let onReveal: (Screenshot) -> Void
    let onCopyPath: (Screenshot) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    private var highlighted: Bool { hovering || focused }
    private let radius: CGFloat = 10

    var body: some View {
        Button { onClick(shot) } label: {
            VStack(spacing: 0) {
                ScreenshotImage(url: shot.url, contentMode: .fill, maxPixel: Int(PopoverMetrics.tile * 3))
                    .frame(width: PopoverMetrics.tile, height: PopoverMetrics.thumbnailHeight, alignment: .topLeading)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: radius))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius)
                            .strokeBorder(highlighted ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: highlighted ? 2 : 0.5)
                    }
                    .overlay(alignment: .topTrailing) {
                        if copied {
                            Label("Copied", systemImage: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7).padding(.vertical, 5)
                                .background(.regularMaterial, in: Capsule()).padding(5)
                        }
                    }
                HStack(spacing: 4) {
                    Text(age).monospacedDigit()
                    Spacer()
                    Image(systemName: "doc.on.doc").opacity(highlighted ? 1 : 0)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
                .frame(height: PopoverMetrics.cardHeight - PopoverMetrics.thumbnailHeight)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            hovering = inside
            onHover(inside ? shot : nil)
        }
        .accessibilityLabel("Copy screenshot, \(shot.url.lastPathComponent)")
        .accessibilityValue(copied ? "Copied" : age)
        .contextMenu {
            Button("Copy Image") { onClick(shot) }
            Button("Show in Finder") { onReveal(shot) }
            Button("Copy Path") { onCopyPath(shot) }
        }
        .help("Click to copy · \(shot.url.lastPathComponent)")
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: highlighted)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: copied)
    }
}

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
                        age: compactRelativeAge(from: shot.captureDate, now: now),
                        onHover: onHover,
                        onClick: onClick,
                        onReveal: onReveal,
                        onCopyPath: onCopyPath)
                }
            }
            .padding(PopoverMetrics.gap)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(OverlayScrollers())
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

/// A single screenshot tile. Owns its hover state so it can reveal the copy
/// affordance and age without re-rendering the whole grid.
private struct GridTile: View {
    let shot: Screenshot
    let copied: Bool
    let age: String
    let onHover: (Screenshot?) -> Void
    let onClick: (Screenshot) -> Void
    let onReveal: (Screenshot) -> Void
    let onCopyPath: (Screenshot) -> Void

    @State private var hovering = false

    private let radius: CGFloat = 8

    var body: some View {
        ScreenshotImage(url: shot.url, contentMode: .fill, maxPixel: Int(PopoverMetrics.tile * 3))
            // Top-anchored so the meaningful top of a screenshot survives the
            // square crop instead of being centered away.
            .frame(width: PopoverMetrics.tile, height: PopoverMetrics.tile, alignment: .top)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: radius))
            // Subtle border so bright web pages don't glow louder than dark shots.
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
            .overlay { hoverChrome }
            .overlay { copiedOverlay }
            .contentShape(RoundedRectangle(cornerRadius: radius))
            .onHover { inside in
                hovering = inside
                onHover(inside ? shot : nil)
            }
            .onTapGesture { onClick(shot) }
            .contextMenu {
                Button("Copy image") { onClick(shot) }
                Button("Open in Finder") { onReveal(shot) }
                Button("Copy path") { onCopyPath(shot) }
            }
            .help("Click to copy")
            .animation(.easeOut(duration: 0.15), value: hovering)
            // Snap in fast, fade out even faster.
            .animation(copied ? .easeOut(duration: 0.10) : .easeIn(duration: 0.06), value: copied)
    }

    /// Copy glyph (top-right) and age pill (bottom-left), shown on hover.
    @ViewBuilder private var hoverChrome: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(.black.opacity(0.55), in: Circle())
                }
                Spacer()
                HStack {
                    Text(age)
                        .font(.system(size: 9, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.55), in: Capsule())
                    Spacer()
                }
            }
            .padding(4)
        }
        .opacity(hovering && !copied ? 1 : 0)
        .allowsHitTesting(false)
    }

    /// Green "Copied" confirmation flashed over the tile after a click.
    @ViewBuilder private var copiedOverlay: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(.black.opacity(0.45))
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                    Text("Copied")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.white)
            }
            .opacity(copied ? 1 : 0)
            .allowsHitTesting(false)
    }
}

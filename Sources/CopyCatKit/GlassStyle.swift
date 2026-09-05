import SwiftUI

/// Glass belongs to controls/navigation, leaving screenshot content unobscured.
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 22
    var interactive = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                content.glassEffect(.regular.interactive(interactive), in: RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            }
            #else
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            #endif
        }
    }
}

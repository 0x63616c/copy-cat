import SwiftUI

/// Single source of truth for the app-wide text scale. Every text style routes
/// through `Font.cc(...)` (or the root `.environment(\.font, .cc(13))`), so the
/// whole UI's type size is one number. Currently +20% over the macOS defaults.
enum Typo {
    static let scale: CGFloat = 1.2

    /// Base macOS point sizes, kept here so call sites read semantically.
    static let body: CGFloat = 13
    static let headline: CGFloat = 13
    static let callout: CGFloat = 12
    static let subheadline: CGFloat = 11
    static let caption2: CGFloat = 10
}

extension Font {
    /// Scaled system font. `base` is the unscaled point size (see `Typo`).
    static func cc(_ base: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: base * Typo.scale, weight: weight)
    }
}

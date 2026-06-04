# copy-cat — Visual & Interaction Design Brief

> **Paste this whole file as the opening prompt to a fresh Claude Code session.** Its job is to *design* copy-cat's UI: a macOS 26 "Liquid Glass" menu bar app, both as a written design system and as working SwiftUI components. It is not implementing the app logic (that is already planned and partly built); it is designing the look, feel, motion, and component library that the views in `Sources/CopyCatKit/` will adopt.

---

## Your role

You are a senior macOS product designer + SwiftUI engineer. Produce a **distinctive, production-grade, unmistakably macOS 26 design** for copy-cat, delivered as (1) a design system document and (2) real, compiling SwiftUI code using the Liquid Glass APIs. Avoid generic "AI default" SwiftUI (plain `.regularMaterial` cards, hairline dividers, system-blue everywhere). This should look like an app Apple would feature.

## Before you design anything

1. **Read `SPEC.md`** (product spec) and **`docs/superpowers/plans/2026-06-04-copy-cat-menu-bar-app.md`** (implementation plan) in this repo. The design must slot into the architecture and view names defined there — do not invent a different structure.
2. **Verify the current macOS 26 / SwiftUI Liquid Glass API surface** against the latest Apple docs before writing code (the API evolved through 2025–2026; names below are the design intent, confirm exact signatures). Use WebFetch on `developer.apple.com` for `glassEffect`, `GlassEffectContainer`, `Glass`, `glassEffectID`, `buttonStyle(.glass)`, concentric shapes, and the "Adopting Liquid Glass" / "Applying Liquid Glass to custom views" HIG pages.
3. **Present, in this order, before producing the design** (the client works this way):
   - **Non-technical assumptions** — UX, product, scope.
   - **Technical assumptions** — APIs, deps, version targets, risks.
   - **Plain-English description** of the design direction.
   Wait for approval on those three, then produce the full design.

## What we're designing (app in one line)

A `LSUIElement` menu bar app: clicking a **black-cat** status icon opens an `NSPopover` whose content is SwiftUI — **preview pane on the left, square-tile screenshot grid on the right** — that auto-copies each new screenshot to the clipboard.

---

## Hard constraints (non-negotiable house style)

1. **Spacing on a single scale.** Define a spacing token set (e.g. 4 / 8 / 12 / 16 / 24) and use it everywhere via layout primitives (`HStack`/`VStack`/`Grid` `spacing:`, `.padding(Token.x)`). **No magic-number nudges** (`+2`, `top: h+4`). If you reach for an eyeballed offset, find the primitive instead — hand-tuned pixel offsets are a code smell.
2. **Consistent, even spacing** across the whole popover. Uniform gutters in the grid, uniform padding in panels.
3. **Dark mode is a first-class target, and scrollbars must be styled in dark mode.** The grid scrolls; ensure the scroll indicators and any scroll edge treatment read correctly on dark glass, not just light. This is the single most-missed detail — check it explicitly.
4. **Layout = structural invariants.** Square tiles stay square via aspect ratio, not fixed math that breaks at other sizes. The grid is `columns × rows` with the column count fixed and rows growing — express that with the layout engine.
5. **Honor accessibility settings on glass.** Glass is gorgeous but fragile: you MUST degrade gracefully for **Reduce Transparency** and **Increase Contrast** (fall back to solid/legible fills) and **Reduce Motion** (drop the morph/shimmer animations). Maintain text contrast over translucent material in every state.
6. **Modern Swift only.** Swift 6.2, strict concurrency-clean. Prefer the Observation framework (`@Observable`) and modern SwiftUI idioms in any view-model glue you write; `#Preview` macros for every component and state.

---

## macOS 26 Liquid Glass — design language to apply

Design *for* Liquid Glass, don't just sprinkle it. Principles + the toolkit:

**Principles**
- Glass is the **floating control/navigation layer above content**, not the content itself. The screenshots are the content; the chrome (header, banner, info panel, buttons, the popover surface) is where glass lives.
- **Defer to content.** Don't drown the thumbnails in effects. Restraint reads as premium.
- **Group related controls** into a single glass container so they share one continuous surface and morph together, rather than N separate glass blobs.
- **Concentricity:** nested rounded shapes should share concentric corner radii (outer container radius ⊋ inner tile radius), so corners stay parallel.

**Toolkit (confirm exact API before use)**
- `.glassEffect(_:in:)` with `Glass` variants: `.regular`, `.clear`, `.tint(_)`, `.interactive()` — for the popover chrome, info panel, banner, and buttons.
- `GlassEffectContainer { … }` to group multiple glass elements so they blend/morph as one (use for the info-panel button cluster and the recovery-button stack).
- `glassEffectID(_:in:)` + a `@Namespace` for smooth morph transitions (e.g. preview swapping on hover, banner appearing/dismissing).
- `.buttonStyle(.glass)` / `.glassProminent` for actions; reserve prominent/tinted glass for the single primary action per surface (Enable, Choose folder…).
- Concentric corners via the concentric rounded-rectangle shape so tiles and containers nest cleanly.
- Scroll edge effects for the grid so content fades under the glass header instead of colliding with it.

**Restraint rules**
- One prominent (tinted) glass action per surface, max. Everything else is regular/clear glass or plain.
- Don't stack glass on glass on glass — flatten to one container where elements are adjacent.

---

## The icon — a little black cat 🐈‍⬛

The brand. Design it properly, don't settle for a generic SF Symbol if you can do better.

- **Menu bar icon:** a sleek, minimal **black cat** silhouette, rendered as a **template image** (monochrome, `isTemplate = true`) so macOS tints it for light/dark menu bars and the active/inactive states. It must read at 16–18pt in the menu bar — simple, bold silhouette, no fine detail that disappears at small size. SF Symbol `cat.fill` is the placeholder/fallback already in the plan; aim to ship a **custom vector** (PDF/SVG, single path) that looks more like a deliberate cat mark.
- **Badge state:** when folder access is unresolved, the icon shows a warning affordance (the plan currently swaps to `exclamationmark.triangle.fill`). Design a nicer integrated treatment if you can — e.g. the cat with a small badge — but keep it template-renderable and legible.
- **App icon:** a matching black-cat mark for `CopyCat.app` (and the asset-catalog sizes). Playful but clean; works on light and dark. Consider the "copy-cat" pun (a cat + a hint of duplication/clipboard) without being cheesy.
- **Deliverable:** provide the cat as an **SVG** (and describe the PDF/asset-catalog setup), plus the SwiftUI usage. If you can generate a clean SVG path for the silhouette, do it.

---

## Surfaces to design (each: layout, glass treatment, light + dark, motion, a11y)

These map 1:1 to views in `Sources/CopyCatKit/` — design each so it drops into that file.

1. **Menu bar status item** (`AppDelegate`) — the cat icon, default + badge states, template rendering.
2. **Popover shell** (`PopoverRootView`) — the overall 720×460 glass surface, the header (title + cog), and how the three content states swap. Header is glass floating over content; grid scrolls under it (scroll edge effect).
3. **Normal state** (`PopoverRootView` → `PreviewPane` + `GridView`):
   - **Grid (right):** square tiles, aspect-fill (crop overflow), newest top-left filling →, then wraps; concentric-corner tiles; hover affordance (lift/scale/glass highlight — respecting Reduce Motion); click = copy with a quick confirmation pulse. Even gutters on the spacing scale. Styled dark scrollbar.
   - **Preview (left):** newest by default, hovered tile on hover, shown at **native aspect ratio** capped to a max; the swap should morph (glassEffectID). Info panel below/alongside in a glass container: capture time + `Open in Finder` / `Copy path` / `Copy image` actions.
4. **Empty state** (`EmptyStateView`) — "No screenshots yet. Press ⌘⇧3 or ⌘⇧4 to take one." Make it charming (the cat, waiting). Centered, glass-aware.
5. **Not-saving banner** (`NotSavingBanner`) — a glass fix-it banner over the content: "Screenshots aren't being saved to disk → Enable", plus the "hide floating thumbnail" action. One prominent glass action (Enable).
6. **No-access state** (`NoAccessView`) — "Can't see your screenshots" with the three recovery routes (Choose folder… / Use a folder that needs no permission / Open System Settings) grouped in one glass container; primary = Choose folder…
7. **Settings sheet** (`SettingsView`) — copy-on-screenshot toggle, save-location picker, grid columns×rows steppers. Clean glass sheet, same spacing scale.
8. **Copy confirmation** — a small, tasteful "copied" affordance when a tile/preview is copied (toast or tile pulse). Reduce-Motion variant.

---

## Architecture contract (so the design is implementable)

- **Views are dumb projections** of `CopyCatCore` types. Do not put logic in views. The data you render:
  - `Screenshot` (`url`, `captureDate`, `id == path`)
  - `AppStatus` (`content: .noAccess | .empty | .normal`, `showNotSavingBanner: Bool`, `autoCopyPaused: Bool`)
  - `GridLayout` (`columns`, `visibleRows`, `needsScroll`, `lastRowCount`) — from `gridLayout(itemCount:columns:maxRows:)`
  - `Settings` (`copyOnScreenshot`, `saveLocationPath`, `gridColumns`, `gridRows`)
  - `previewTarget(hovered:newest:)` and `badgeSymbolName(for:)` helpers
- Views receive an `AppController` (`@MainActor`, observable) via the environment and call its action methods (`copy`, `enableFileTarget`, `chooseFolder`, `useEscapeHatch`, `openPrivacySettings`, `revealInFinder`, `copyPath`). Don't add new responsibilities to it; if a design needs new state, propose it as a typed addition to `CopyCatCore`, not ad-hoc `@State` logic.
- Must render inside an `NSPopover` (fixed-ish content size, transient behavior). Respect that you're chrome over a vibrant background.
- **Performance:** the grid can hold many screenshots — lazy loading, downsampled thumbnails (don't decode full-res images into tiles), smooth scroll. Note any thumbnail-cache approach you assume.

## Deliverables

1. **`docs/design-system.md`** — tokens (spacing scale, corner-radius scale incl. concentric pairs, tile sizing rules, typography ramp using SF Pro / system, color & material usage, glass-variant usage map, motion specs with durations/curves and the Reduce-Motion fallbacks), plus a per-surface spec section (each surface above: layout, glass treatment, states, a11y). Numbered lists grouped under short bold headers, minimal prose.
2. **`Sources/CopyCatKit/DesignSystem.swift`** — the tokens as Swift (spacing, radii, a `Tokens` enum or similar; glass helper view modifiers; reusable `GlassPanel`/`GlassActionGroup` wrappers). One source of truth the views import.
3. **Updated SwiftUI for the views** in `Sources/CopyCatKit/` (`PopoverRootView`, `GridView`, `PreviewPane`, `StateViews`, `SettingsView`) adopting the design system and Liquid Glass — compiling, with `#Preview`s for **every state in both light and dark**.
4. **The cat icon** — SVG (menu bar silhouette + app icon), template-rendering setup, and the asset-catalog/usage notes.
5. **Rationale** — short notes on the key design decisions and how each honors the constraints (esp. a11y/glass degradation and dark-mode scrollbars).

## Out of scope (mirror the spec)

Editing/annotation, cloud upload/sharing, OCR, screen recording, in-app search. Design v1 only.

---

## Definition of done

- Builds and previews in both color schemes; Reduce Transparency / Reduce Motion / Increase Contrast all degrade gracefully and remain legible.
- Spacing is uniform and token-driven; no magic-number offsets.
- Dark-mode scroll indicators are explicitly handled.
- Glass is used as a floating chrome layer with restraint (one prominent action per surface), grouped in containers, concentric corners respected.
- The black-cat icon reads cleanly at menu bar size and as an app icon.
- Everything maps onto the existing `CopyCatCore` types and `CopyCatKit` view names — no architectural drift.

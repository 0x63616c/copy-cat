# copy-cat — Product Spec

**What it is:** A macOS menu bar app that auto-copies every new screenshot to the clipboard, and gives you a quick-access grid of your recent screenshots.

## Core behavior
- On every new screenshot (⌘⇧3, ⌘⇧4, or ⌘⇧5): copy the image to the clipboard automatically. The file still saves to disk.
- Runs as a menu bar agent (no Dock icon).
- Screenshots are identified by the macOS Spotlight flag `kMDItemIsScreenCapture == 1`, not by filename, so it works even in a folder mixed with other images. A live `NSMetadataQuery` provides detection, the "new screenshot" trigger, and the grid feed in one mechanism. Fallback to a `Screenshot*` filename heuristic if Spotlight indexing is disabled for the location.

## Menu bar popover
Clicking the icon opens a popover with two regions: **preview left, grid right.**

**Grid (right)**
- Square tiles, aspect-fill (fill the square, crop overflow).
- **Newest top-left**, fills left→right, then wraps down.
- Visible size is M columns × N rows (configurable, default 3 × 5).
- **Sizes to content, up to the M×N cap.** Columns fixed at M; rows grow 0→N as needed, then scroll for older ones. No empty placeholder squares. A partial last row is left-aligned in newest-order.
- Click a tile → copy that image.

**Preview (left)**
- Hovering a tile shows it larger, at **native aspect ratio**, capped to a max size.
- Default (before hover) shows the newest screenshot, so the pane is never blank.
- Info panel alongside: capture time, **Open in Finder**, **Copy path**, **Copy image**.

## Settings (cog)
1. Copy on screenshot? (toggle)
2. Save location (folder picker)
3. Grid size (columns × rows)

## States
- **Normal** — grid + preview as above.
- **Empty (no screenshots yet)** — "No screenshots yet. Press ⌘⇧3 or ⌘⇧4 to take one."
- **Not saving to disk** — macOS is set to clipboard-only (`com.apple.screencapture target != file`). Show a fix-it banner: "Screenshots aren't being saved to disk → Enable", which sets `target = file` in one click. Same place can offer to disable the floating thumbnail for instant copy.
- **No access** — folder is TCC-protected and access was denied. Show a "can't see your screenshots" state with three recovery routes:
  1. **Choose folder…** (`NSOpenPanel`) — picking the folder *is* the consent; works even after a denial.
  2. **Use a folder that needs no permission** — points the save location to `~/Pictures/Screenshots` (app-owned, never prompts). Guaranteed escape hatch.
  3. **Open System Settings** — deep-link to Privacy & Security → Files and Folders.
  - Menu bar icon shows a badge while inactive; auto-copy pauses until access is resolved, then resumes and back-fills.

## Storage & permissions
- Does **not** relocate screenshots. Reads them wherever they already save (macOS default: `~/Desktop`).
- If that location is TCC-protected (Desktop/Documents/Downloads), the app requests access via the standard one-time macOS consent prompt. Mac App Store (sandboxed) build: user grants the folder once via a file panel (security-scoped bookmark).
- App's own state (config, index) lives in `~/Library/Application Support/copy-cat/`.

## Tech & distribution
- Swift + SwiftUI/AppKit. `NSStatusItem` + `LSUIElement`, `NSPopover`, `NSMetadataQuery`.
- Signed + notarized (Developer ID) for direct download.

## Out of scope (v1)
- Editing/annotation, cloud upload/sharing, OCR, screen recording, search.

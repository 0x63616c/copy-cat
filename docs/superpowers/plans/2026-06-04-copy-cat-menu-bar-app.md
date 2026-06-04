# copy-cat Menu Bar App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that auto-copies every new screenshot to the clipboard and shows a quick-access grid of recent screenshots.

**Architecture:** Three Swift Package targets so everything testable is in a library:
- `CopyCatCore` — pure logic, **no AppKit** (detection diffing, grid math, app-state reducer, settings, screencapture derivations, view-logic helpers). Fully unit-tested with Swift Testing.
- `CopyCatKit` — AppKit/SwiftUI but **injectable** (clipboard, screencapture prefs, folder access, live detector, `AppController` coordinator, and all SwiftUI views). Depends on `CopyCatCore`. The `AppController` is TDD'd against fakes; views get ViewInspector structure tests.
- `CopyCat` — a one-line executable shim that calls `CopyCatKit.runApp()`.

System I/O sits behind protocols (`Clipboard`, `ScreencapturePreferences`, `FolderAccessing`) so the coordinator's auto-copy/pause/back-fill logic is driven by tests, not Spotlight. A `scripts/bundle.sh` wraps the executable into a `CopyCat.app` with an `LSUIElement` Info.plist for run/sign/notarize.

**Tech Stack:** Swift 6.2, Swift Package Manager, SwiftUI + AppKit, `NSStatusItem`, `NSPopover`, `NSMetadataQuery`, `NSPasteboard`, Swift Testing (`import Testing`), ViewInspector (SwiftUI structure tests), `codesign`/`notarytool`.

**Why the three-target split:** SPM test targets cannot `@testable import` an executable target. Putting the coordinator and views in the `CopyCatKit` library is what makes them unit-testable at all. The executable becomes a trivial shim with nothing worth testing.

---

## File Structure

**`Sources/CopyCatCore/` (pure, TDD):**
- `Version.swift` — version constant.
- `Screenshot.swift` — `Screenshot` value type (id = path, url, captureDate).
- `GridLayout.swift` — `gridLayout(itemCount:columns:maxRows:)`.
- `AppStatus.swift` — `ContentState`, `AppStatus`, `resolveStatus(...)`.
- `Settings.swift` — `Settings` Codable model + `SettingsStore` + config URL.
- `Detection.swift` — `isScreenshot`, `sortedNewestFirst`, `newScreenshots`.
- `ScreencaptureDerivation.swift` — `isProtectedLocation`, `savingToDisk`.
- `ViewLogic.swift` — `previewTarget(hovered:newest:)`, `badgeSymbolName(for:)`.

**`Sources/CopyCatKit/` (AppKit/SwiftUI, injectable — TDD where logic lives):**
- `Clipboard.swift` — `Clipboard` protocol + `NSPasteboardClipboard`.
- `ScreencapturePreferences.swift` — protocol + `SystemScreencapturePreferences`.
- `FolderAccess.swift` — `FolderAccessing` protocol + `FolderAccess` impl.
- `ScreenshotDetector.swift` — `NSMetadataQuery` live wrapper feeding core helpers.
- `AppController.swift` — `@MainActor ObservableObject` coordinator (TDD'd via fakes).
- `AppDelegate.swift` — `NSStatusItem`, `NSPopover`, badge, plus `public func runApp()`.
- `ScreenshotThumbnail.swift` — `ScreenshotImage` NSImage loader.
- `GridView.swift` — the tile grid.
- `PreviewPane.swift` — hover preview + info panel.
- `StateViews.swift` — empty, no-access, not-saving banner.
- `SettingsView.swift` — the cog sheet.
- `PopoverRootView.swift` — top-level switch over `ContentState` + banner.

**`Sources/CopyCat/` (executable shim):**
- `main.swift` — `import CopyCatKit; runApp()`.

**Tests:**
- `Tests/CopyCatCoreTests/` — one file per `CopyCatCore` file.
- `Tests/CopyCatKitTests/` — `AppControllerTests.swift` (Swift Testing + fakes), `Fakes.swift`, `UIStructureTests.swift` (XCTest + ViewInspector).

**Build/dist — `scripts/`:** `bundle.sh`, `sign-notarize.sh`, plus `Resources/Info.plist.template`.

---

## Task 1: Package scaffolding (3 targets + 2 test targets)

**Files:**
- Create: `Package.swift`
- Create: `Sources/CopyCatCore/Version.swift`
- Create: `Sources/CopyCatKit/Bootstrap.swift`
- Create: `Sources/CopyCat/main.swift`
- Test: `Tests/CopyCatCoreTests/VersionTests.swift`
- Modify: `.gitignore`

- [ ] **Step 1: Write `Package.swift`** (ViewInspector dependency is added later in Task 21)

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CopyCat",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CopyCatCore"),
        .target(name: "CopyCatKit", dependencies: ["CopyCatCore"]),
        .executableTarget(name: "CopyCat", dependencies: ["CopyCatKit"]),
        .testTarget(name: "CopyCatCoreTests", dependencies: ["CopyCatCore"]),
        .testTarget(name: "CopyCatKitTests", dependencies: ["CopyCatKit"]),
    ]
)
```

- [ ] **Step 2: Write the failing test**

`Tests/CopyCatCoreTests/VersionTests.swift`:

```swift
import Testing
@testable import CopyCatCore

@Test func versionIsNonEmpty() {
    #expect(!CopyCatCore.version.isEmpty)
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --filter versionIsNonEmpty`
Expected: FAIL — `CopyCatCore.version` is not defined.

- [ ] **Step 4: Write minimal sources**

`Sources/CopyCatCore/Version.swift`:

```swift
public enum CopyCatCore {
    public static let version = "0.1.0"
}
```

`Sources/CopyCatKit/Bootstrap.swift` (placeholder; real body lands in Task 15):

```swift
import Foundation

/// Entry point invoked by the executable shim. Replaced in Task 15.
public func runApp() {
    print("copy-cat starting")
}
```

`Sources/CopyCat/main.swift`:

```swift
import CopyCatKit

runApp()
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `swift test --filter versionIsNonEmpty`
Expected: PASS.

- [ ] **Step 6: Update `.gitignore`**

Append:

```
.build/
*.app
DerivedData/
```

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources Tests .gitignore
git commit -m "feat: scaffold CopyCat package (core + kit libs + executable shim + tests)"
```

---

## Task 2: Screenshot model

**Files:**
- Create: `Sources/CopyCatCore/Screenshot.swift`
- Test: `Tests/CopyCatCoreTests/ScreenshotTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/CopyCatCoreTests/ScreenshotTests.swift`:

```swift
import Foundation
import Testing
@testable import CopyCatCore

@Test func screenshotIdIsItsPath() {
    let url = URL(fileURLWithPath: "/tmp/Screenshot 2026-06-04 at 10.00.00.png")
    let shot = Screenshot(url: url, captureDate: Date(timeIntervalSince1970: 100))
    #expect(shot.id == url.path)
}

@Test func screenshotsWithSamePathAreEqual() {
    let url = URL(fileURLWithPath: "/tmp/a.png")
    let a = Screenshot(url: url, captureDate: Date(timeIntervalSince1970: 1))
    let b = Screenshot(url: url, captureDate: Date(timeIntervalSince1970: 2))
    #expect(a == b) // identity is the path, not the date
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter Screenshot`
Expected: FAIL — `Screenshot` is undefined.

- [ ] **Step 3: Write minimal implementation**

`Sources/CopyCatCore/Screenshot.swift`:

```swift
import Foundation

/// A single screenshot on disk. Identity is the file path so the same file
/// compares equal regardless of metadata we attach to it.
public struct Screenshot: Identifiable, Hashable, Sendable {
    public let url: URL
    public let captureDate: Date

    public init(url: URL, captureDate: Date) {
        self.url = url
        self.captureDate = captureDate
    }

    public var id: String { url.path }

    public static func == (lhs: Screenshot, rhs: Screenshot) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter Screenshot`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/CopyCatCore/Screenshot.swift Tests/CopyCatCoreTests/ScreenshotTests.swift
git commit -m "feat: add Screenshot value type keyed by file path"
```

---

## Task 3: Grid layout math

Implements the grid sizing rule: columns fixed at M, rows grow 0→N then scroll, partial last row left-aligned, no empty placeholders.

**Files:**
- Create: `Sources/CopyCatCore/GridLayout.swift`
- Test: `Tests/CopyCatCoreTests/GridLayoutTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/CopyCatCoreTests/GridLayoutTests.swift`:

```swift
import Testing
@testable import CopyCatCore

@Test func emptyGridHasNoRows() {
    let g = gridLayout(itemCount: 0, columns: 3, maxRows: 5)
    #expect(g == GridLayout(columns: 3, visibleRows: 0, needsScroll: false, lastRowCount: 0))
}

@Test func partialFirstRowIsLeftAligned() {
    let g = gridLayout(itemCount: 2, columns: 3, maxRows: 5)
    #expect(g == GridLayout(columns: 3, visibleRows: 1, needsScroll: false, lastRowCount: 2))
}

@Test func fullRowReportsFullLastRowCount() {
    let g = gridLayout(itemCount: 6, columns: 3, maxRows: 5)
    #expect(g == GridLayout(columns: 3, visibleRows: 2, needsScroll: false, lastRowCount: 3))
}

@Test func growsUpToMaxRowsThenScrolls() {
    let g = gridLayout(itemCount: 20, columns: 3, maxRows: 5)
    #expect(g.visibleRows == 5)
    #expect(g.needsScroll == true)
    #expect(g.lastRowCount == 2) // 20 % 3
}

@Test func exactlyAtCapDoesNotScroll() {
    let g = gridLayout(itemCount: 15, columns: 3, maxRows: 5)
    #expect(g.visibleRows == 5)
    #expect(g.needsScroll == false)
    #expect(g.lastRowCount == 3)
}

@Test func clampsNonPositiveColumnsToOne() {
    let g = gridLayout(itemCount: 4, columns: 0, maxRows: 5)
    #expect(g.columns == 1)
    #expect(g.visibleRows == 4)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter Grid`
Expected: FAIL — `gridLayout` / `GridLayout` undefined.

- [ ] **Step 3: Write minimal implementation**

`Sources/CopyCatCore/GridLayout.swift`:

```swift
import Foundation

/// Resolved geometry for the screenshot grid.
public struct GridLayout: Equatable, Sendable {
    public let columns: Int
    /// Rows actually shown (0...maxRows). Older rows beyond this scroll.
    public let visibleRows: Int
    /// True when there are more rows than fit, i.e. the grid must scroll.
    public let needsScroll: Bool
    /// Number of tiles in the final (newest-order, left-aligned) row.
    public let lastRowCount: Int

    public init(columns: Int, visibleRows: Int, needsScroll: Bool, lastRowCount: Int) {
        self.columns = columns
        self.visibleRows = visibleRows
        self.needsScroll = needsScroll
        self.lastRowCount = lastRowCount
    }
}

/// Computes grid geometry. Columns are fixed at `columns`; rows grow from 0 up
/// to `maxRows`, after which the grid scrolls. The last row is left-aligned and
/// may be partial (no empty placeholder tiles).
public func gridLayout(itemCount: Int, columns: Int, maxRows: Int) -> GridLayout {
    let cols = max(1, columns)
    let cap = max(0, maxRows)
    let count = max(0, itemCount)

    guard count > 0 else {
        return GridLayout(columns: cols, visibleRows: 0, needsScroll: false, lastRowCount: 0)
    }

    let rowsNeeded = (count + cols - 1) / cols
    let visibleRows = min(rowsNeeded, cap)
    let needsScroll = rowsNeeded > cap
    let remainder = count % cols
    let lastRowCount = remainder == 0 ? cols : remainder

    return GridLayout(
        columns: cols,
        visibleRows: visibleRows,
        needsScroll: needsScroll,
        lastRowCount: lastRowCount
    )
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter Grid`
Expected: PASS (all six tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/CopyCatCore/GridLayout.swift Tests/CopyCatCoreTests/GridLayoutTests.swift
git commit -m "feat: add pure grid layout math (fixed cols, growing rows, partial last row)"
```

---

## Task 4: App state reducer

Maps three inputs (folder access, saving-to-disk, screenshot count) to the UI state.

**Files:**
- Create: `Sources/CopyCatCore/AppStatus.swift`
- Test: `Tests/CopyCatCoreTests/AppStatusTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/CopyCatCoreTests/AppStatusTests.swift`:

```swift
import Testing
@testable import CopyCatCore

@Test func noAccessTrumpsEverythingAndPausesCopy() {
    let s = resolveStatus(hasAccess: false, savingToDisk: true, screenshotCount: 9)
    #expect(s.content == .noAccess)
    #expect(s.autoCopyPaused == true)
    #expect(s.showNotSavingBanner == false)
}

@Test func emptyWhenAccessibleButNoScreenshots() {
    let s = resolveStatus(hasAccess: true, savingToDisk: true, screenshotCount: 0)
    #expect(s.content == .empty)
    #expect(s.autoCopyPaused == false)
    #expect(s.showNotSavingBanner == false)
}

@Test func normalWhenAccessibleWithScreenshots() {
    let s = resolveStatus(hasAccess: true, savingToDisk: true, screenshotCount: 3)
    #expect(s.content == .normal)
    #expect(s.showNotSavingBanner == false)
}

@Test func notSavingBannerShowsOverContentWhenAccessible() {
    let s = resolveStatus(hasAccess: true, savingToDisk: false, screenshotCount: 3)
    #expect(s.content == .normal)
    #expect(s.showNotSavingBanner == true)
    #expect(s.autoCopyPaused == false)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter AppStatus`
Expected: FAIL — `resolveStatus` / `AppStatus` undefined.

- [ ] **Step 3: Write minimal implementation**

`Sources/CopyCatCore/AppStatus.swift`:

```swift
import Foundation

/// Which content region fills the popover body.
public enum ContentState: Equatable, Sendable {
    case noAccess   // folder is TCC-protected and denied; recovery routes
    case empty      // accessible, but zero screenshots
    case normal     // accessible, grid + preview
}

/// Full derived UI state for the popover.
public struct AppStatus: Equatable, Sendable {
    public let content: ContentState
    public let showNotSavingBanner: Bool
    public let autoCopyPaused: Bool

    public init(content: ContentState, showNotSavingBanner: Bool, autoCopyPaused: Bool) {
        self.content = content
        self.showNotSavingBanner = showNotSavingBanner
        self.autoCopyPaused = autoCopyPaused
    }
}

/// Derives the popover state. Access is the highest-priority signal: with no
/// access we show the recovery state and pause auto-copy. Otherwise content is
/// empty vs normal by count, and the not-saving banner overlays either.
public func resolveStatus(
    hasAccess: Bool,
    savingToDisk: Bool,
    screenshotCount: Int
) -> AppStatus {
    guard hasAccess else {
        return AppStatus(content: .noAccess, showNotSavingBanner: false, autoCopyPaused: true)
    }
    let content: ContentState = screenshotCount > 0 ? .normal : .empty
    return AppStatus(
        content: content,
        showNotSavingBanner: !savingToDisk,
        autoCopyPaused: false
    )
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter AppStatus`
Expected: PASS (all four tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/CopyCatCore/AppStatus.swift Tests/CopyCatCoreTests/AppStatusTests.swift
git commit -m "feat: add app-state reducer (access > empty/normal + not-saving banner)"
```

---

## Task 5: Settings model and store

**Files:**
- Create: `Sources/CopyCatCore/Settings.swift`
- Test: `Tests/CopyCatCoreTests/SettingsTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/CopyCatCoreTests/SettingsTests.swift`:

```swift
import Foundation
import Testing
@testable import CopyCatCore

@Test func defaultsMatchSpec() {
    let d = Settings.defaults
    #expect(d.copyOnScreenshot == true)
    #expect(d.gridColumns == 3)
    #expect(d.gridRows == 5)
    #expect(d.saveLocationPath == nil)
}

@Test func settingsRoundTripThroughJSON() throws {
    var s = Settings.defaults
    s.copyOnScreenshot = false
    s.gridColumns = 4
    s.gridRows = 6
    s.saveLocationPath = "/Users/x/Pictures/Screenshots"
    let data = try JSONEncoder().encode(s)
    let back = try JSONDecoder().decode(Settings.self, from: data)
    #expect(back == s)
}

@Test func gridDimensionsClampToSaneRange() {
    var s = Settings.defaults
    s.gridColumns = 0
    s.gridRows = 99
    let clamped = s.clamped()
    #expect(clamped.gridColumns >= 1)
    #expect(clamped.gridRows <= 12)
}

@Test func configURLLivesUnderApplicationSupport() {
    let url = Settings.configURL()
    #expect(url.path.contains("Application Support/copy-cat"))
    #expect(url.lastPathComponent == "config.json")
}

@Test func storeSavesAndLoadsFromDisk() throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("copy-cat-test-\(UUID().uuidString)")
        .appendingPathComponent("config.json")
    let store = SettingsStore(url: tmp)
    var s = Settings.defaults
    s.gridColumns = 4
    try store.save(s)
    #expect(store.load().gridColumns == 4)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter Settings`
Expected: FAIL — `Settings` undefined.

- [ ] **Step 3: Write minimal implementation**

`Sources/CopyCatCore/Settings.swift`:

```swift
import Foundation

/// User-configurable settings, persisted as JSON under Application Support.
public struct Settings: Codable, Equatable, Sendable {
    public var copyOnScreenshot: Bool
    /// Folder to watch. `nil` means "use the macOS screencapture location".
    public var saveLocationPath: String?
    public var gridColumns: Int
    public var gridRows: Int

    public init(copyOnScreenshot: Bool, saveLocationPath: String?, gridColumns: Int, gridRows: Int) {
        self.copyOnScreenshot = copyOnScreenshot
        self.saveLocationPath = saveLocationPath
        self.gridColumns = gridColumns
        self.gridRows = gridRows
    }

    public static let defaults = Settings(
        copyOnScreenshot: true,
        saveLocationPath: nil,
        gridColumns: 3,
        gridRows: 5
    )

    /// Clamps grid dimensions to a usable range for the popover.
    public func clamped() -> Settings {
        var copy = self
        copy.gridColumns = min(max(1, gridColumns), 8)
        copy.gridRows = min(max(1, gridRows), 12)
        return copy
    }

    /// `~/Library/Application Support/copy-cat/config.json`
    public static func configURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("copy-cat", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }
}

/// Loads and saves `Settings` to disk, falling back to defaults on any error.
public struct SettingsStore: Sendable {
    private let url: URL

    public init(url: URL = Settings.configURL()) {
        self.url = url
    }

    public func load() -> Settings {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Settings.self, from: data) else {
            return .defaults
        }
        return decoded.clamped()
    }

    public func save(_ settings: Settings) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings.clamped()).write(to: url, options: .atomic)
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter Settings`
Expected: PASS (all five tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/CopyCatCore/Settings.swift Tests/CopyCatCoreTests/SettingsTests.swift
git commit -m "feat: add Settings model + JSON store under Application Support"
```

---

## Task 6: Detection diff helpers

**Files:**
- Create: `Sources/CopyCatCore/Detection.swift`
- Test: `Tests/CopyCatCoreTests/DetectionTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/CopyCatCoreTests/DetectionTests.swift`:

```swift
import Foundation
import Testing
@testable import CopyCatCore

private func shot(_ path: String, _ t: TimeInterval) -> Screenshot {
    Screenshot(url: URL(fileURLWithPath: path), captureDate: Date(timeIntervalSince1970: t))
}

@Test func spotlightFlagWinsRegardlessOfName() {
    #expect(isScreenshot(isScreenCaptureFlag: true, fileName: "random.png") == true)
    #expect(isScreenshot(isScreenCaptureFlag: false, fileName: "Screenshot 1.png") == false)
}

@Test func fallsBackToFilenameWhenFlagUnknown() {
    #expect(isScreenshot(isScreenCaptureFlag: nil, fileName: "Screenshot 2026-06-04.png") == true)
    #expect(isScreenshot(isScreenCaptureFlag: nil, fileName: "CleanShot.png") == false)
}

@Test func sortsNewestFirst() {
    let sorted = sortedNewestFirst([shot("/a", 10), shot("/b", 30), shot("/c", 20)])
    #expect(sorted.map(\.url.lastPathComponent) == ["b", "c", "a"])
}

@Test func newScreenshotsReturnsOnlyUnseenNewestFirst() {
    let previous: Set<String> = ["/a"]
    let current = [shot("/a", 10), shot("/b", 30), shot("/c", 20)]
    let fresh = newScreenshots(previousIDs: previous, current: current)
    #expect(fresh.map(\.url.lastPathComponent) == ["b", "c"])
}

@Test func noNewScreenshotsWhenAllSeen() {
    let fresh = newScreenshots(previousIDs: ["/a", "/b"], current: [shot("/a", 1), shot("/b", 2)])
    #expect(fresh.isEmpty)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter Detection`
Expected: FAIL — helpers undefined.

- [ ] **Step 3: Write minimal implementation**

`Sources/CopyCatCore/Detection.swift`:

```swift
import Foundation

/// Decides whether a file is a screenshot. The Spotlight
/// `kMDItemIsScreenCapture` flag is authoritative; when it is unavailable
/// (Spotlight disabled for the location) we fall back to the macOS default
/// "Screenshot*" filename heuristic.
public func isScreenshot(isScreenCaptureFlag: Bool?, fileName: String) -> Bool {
    if let flag = isScreenCaptureFlag {
        return flag
    }
    return fileName.hasPrefix("Screenshot")
}

/// Newest capture first.
public func sortedNewestFirst(_ items: [Screenshot]) -> [Screenshot] {
    items.sorted { $0.captureDate > $1.captureDate }
}

/// Returns items not present in `previousIDs`, newest first.
public func newScreenshots(previousIDs: Set<String>, current: [Screenshot]) -> [Screenshot] {
    sortedNewestFirst(current.filter { !previousIDs.contains($0.id) })
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter Detection`
Expected: PASS (all five tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/CopyCatCore/Detection.swift Tests/CopyCatCoreTests/DetectionTests.swift
git commit -m "feat: add detection helpers (flag+filename, sort, diff)"
```

---

## Task 7: Screencapture-defaults derivation

**Files:**
- Create: `Sources/CopyCatCore/ScreencaptureDerivation.swift`
- Test: `Tests/CopyCatCoreTests/ScreencaptureDerivationTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/CopyCatCoreTests/ScreencaptureDerivationTests.swift`:

```swift
import Testing
@testable import CopyCatCore

@Test func protectedZonesAreDetected() {
    let home = "/Users/x"
    #expect(isProtectedLocation("/Users/x/Desktop", home: home) == true)
    #expect(isProtectedLocation("/Users/x/Desktop/Shots", home: home) == true)
    #expect(isProtectedLocation("/Users/x/Documents", home: home) == true)
    #expect(isProtectedLocation("/Users/x/Downloads/sub", home: home) == true)
}

@Test func ownFoldersAreNotProtected() {
    let home = "/Users/x"
    #expect(isProtectedLocation("/Users/x/Pictures/Screenshots", home: home) == false)
    #expect(isProtectedLocation("/Users/x/Screenshots", home: home) == false)
}

@Test func savingToDiskWhenTargetMissingOrFile() {
    #expect(savingToDisk(target: nil) == true)
    #expect(savingToDisk(target: "file") == true)
}

@Test func notSavingToDiskWhenClipboardOnly() {
    #expect(savingToDisk(target: "clipboard") == false)
    #expect(savingToDisk(target: "preview") == false)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter ScreencaptureDerivation`
Expected: FAIL — helpers undefined.

- [ ] **Step 3: Write minimal implementation**

`Sources/CopyCatCore/ScreencaptureDerivation.swift`:

```swift
import Foundation

/// True when `path` lives inside a TCC-protected zone (Desktop, Documents,
/// Downloads) where a background process needs explicit consent to read.
public func isProtectedLocation(_ path: String, home: String) -> Bool {
    let normalized = (path as NSString).standardizingPath
    for zone in ["Desktop", "Documents", "Downloads"] {
        let root = "\(home)/\(zone)"
        if normalized == root || normalized.hasPrefix(root + "/") {
            return true
        }
    }
    return false
}

/// Whether macOS will write screenshots to a file. `com.apple.screencapture`
/// `target` defaults to `file` when unset; any non-file target (e.g.
/// `clipboard`, `preview`) means nothing lands on disk.
public func savingToDisk(target: String?) -> Bool {
    guard let target, !target.isEmpty else { return true }
    return target == "file"
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter ScreencaptureDerivation`
Expected: PASS (all four tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/CopyCatCore/ScreencaptureDerivation.swift Tests/CopyCatCoreTests/ScreencaptureDerivationTests.swift
git commit -m "feat: add screencapture-defaults derivations (protected zone, saving-to-disk)"
```

---

## Task 8: View-logic helpers (pure, TDD)

The two decisions that would otherwise hide inside views: which screenshot the preview shows, and which menu bar symbol to display. Extracted to `CopyCatCore` so they're unit-tested instead of eyeballed. The menu bar icon is a black cat (`cat.fill`); the no-access badge swaps to a warning triangle.

**Files:**
- Create: `Sources/CopyCatCore/ViewLogic.swift`
- Test: `Tests/CopyCatCoreTests/ViewLogicTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/CopyCatCoreTests/ViewLogicTests.swift`:

```swift
import Foundation
import Testing
@testable import CopyCatCore

@Test func previewPrefersHoverThenNewest() {
    let a = Screenshot(url: URL(fileURLWithPath: "/a"), captureDate: Date(timeIntervalSince1970: 1))
    let b = Screenshot(url: URL(fileURLWithPath: "/b"), captureDate: Date(timeIntervalSince1970: 2))
    #expect(previewTarget(hovered: a, newest: b) == a)
    #expect(previewTarget(hovered: nil, newest: b) == b)
    #expect(previewTarget(hovered: nil, newest: nil) == nil)
}

@Test func badgeIsBlackCatNormallyAndWarningWhenNoAccess() {
    #expect(badgeSymbolName(for: .normal) == "cat.fill")
    #expect(badgeSymbolName(for: .empty) == "cat.fill")
    #expect(badgeSymbolName(for: .noAccess) == "exclamationmark.triangle.fill")
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter ViewLogic`
Expected: FAIL — `previewTarget` / `badgeSymbolName` undefined.

- [ ] **Step 3: Write minimal implementation**

`Sources/CopyCatCore/ViewLogic.swift`:

```swift
import Foundation

/// The screenshot the preview pane should show: the hovered tile if any,
/// otherwise the newest (so the pane is never blank).
public func previewTarget(hovered: Screenshot?, newest: Screenshot?) -> Screenshot? {
    hovered ?? newest
}

/// SF Symbol name for the menu bar item. A black cat normally; a warning badge
/// while folder access is unresolved.
public func badgeSymbolName(for content: ContentState) -> String {
    content == .noAccess ? "exclamationmark.triangle.fill" : "cat.fill"
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter ViewLogic`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/CopyCatCore/ViewLogic.swift Tests/CopyCatCoreTests/ViewLogicTests.swift
git commit -m "feat: add pure view-logic helpers (preview target, menu bar badge)"
```

---

## Task 9: Clipboard wrapper

**Files:**
- Create: `Sources/CopyCatKit/Clipboard.swift`

- [ ] **Step 1: Write the implementation**

`Sources/CopyCatKit/Clipboard.swift`:

```swift
import AppKit

/// Copies an image file's contents onto the system pasteboard.
public protocol Clipboard: Sendable {
    @discardableResult
    func copyImage(at url: URL) -> Bool
}

public struct NSPasteboardClipboard: Clipboard {
    public init() {}

    @discardableResult
    public func copyImage(at url: URL) -> Bool {
        guard let image = NSImage(contentsOf: url) else { return false }
        let pb = NSPasteboard.general
        pb.clearContents()
        return pb.writeObjects([image])
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/CopyCatKit/Clipboard.swift
git commit -m "feat: add NSPasteboard clipboard wrapper (protocol + impl)"
```

---

## Task 10: Screencapture preferences wrapper

**Files:**
- Create: `Sources/CopyCatKit/ScreencapturePreferences.swift`

- [ ] **Step 1: Write the implementation**

`Sources/CopyCatKit/ScreencapturePreferences.swift`:

```swift
import Foundation
import CopyCatCore

/// Read/write access to the macOS screenshot preferences domain.
public protocol ScreencapturePreferences: Sendable {
    var locationPath: String? { get }
    var target: String? { get }
    func enableFileTarget()
    func disableThumbnail()
}

public extension ScreencapturePreferences {
    /// Is macOS currently saving screenshots to disk?
    var isSavingToDisk: Bool { savingToDisk(target: target) }

    /// The resolved folder to watch when settings don't override it.
    func resolvedLocation(home: String) -> String {
        locationPath ?? "\(home)/Desktop"
    }
}

public struct SystemScreencapturePreferences: ScreencapturePreferences {
    private let domain = "com.apple.screencapture"
    private var defaults: UserDefaults? { UserDefaults(suiteName: domain) }

    public init() {}

    public var locationPath: String? {
        guard let raw = defaults?.string(forKey: "location"), !raw.isEmpty else { return nil }
        return (raw as NSString).expandingTildeInPath
    }

    public var target: String? {
        let raw = defaults?.string(forKey: "target")
        return (raw?.isEmpty ?? true) ? nil : raw
    }

    public func enableFileTarget() {
        defaults?.set("file", forKey: "target")
        defaults?.synchronize()
    }

    public func disableThumbnail() {
        defaults?.set(false, forKey: "show-thumbnail")
        defaults?.synchronize()
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Manual smoke check (read path)**

Run: `defaults read com.apple.screencapture 2>/dev/null || echo "(unset — defaults apply)"`
Confirm the keys you read (`location`, `target`) match what `defaults` reports. No assertion.

- [ ] **Step 4: Commit**

```bash
git add Sources/CopyCatKit/ScreencapturePreferences.swift
git commit -m "feat: add screencapture preferences wrapper (read location/target, fix-it writes)"
```

---

## Task 11: Folder access protocol + bookmark store

**Files:**
- Create: `Sources/CopyCatKit/FolderAccess.swift`

- [ ] **Step 1: Write the implementation**

`Sources/CopyCatKit/FolderAccess.swift`:

```swift
import AppKit

/// Abstracts folder-access probing + consent persistence so the coordinator can
/// be tested with a fake.
public protocol FolderAccessing: Sendable {
    func canRead(path: String) -> Bool
    func saveBookmark(for url: URL)
    func resolveBookmark() -> URL?
    func escapeHatchFolder() -> URL
}

public struct FolderAccess: FolderAccessing {
    private let bookmarkURL: URL

    public init(bookmarkURL: URL = FolderAccess.defaultBookmarkURL()) {
        self.bookmarkURL = bookmarkURL
    }

    public static func defaultBookmarkURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("copy-cat", isDirectory: true)
            .appendingPathComponent("folder.bookmark", isDirectory: false)
    }

    public func canRead(path: String) -> Bool {
        FileManager.default.isReadableFile(atPath: path)
            && (try? FileManager.default.contentsOfDirectory(atPath: path)) != nil
    }

    public func saveBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        try? FileManager.default.createDirectory(
            at: bookmarkURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: bookmarkURL, options: .atomic)
    }

    public func resolveBookmark() -> URL? {
        guard let data = try? Data(contentsOf: bookmarkURL) else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    public func escapeHatchFolder() -> URL {
        let url = FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/CopyCatKit/FolderAccess.swift
git commit -m "feat: add FolderAccessing protocol + security-scoped bookmark store"
```

---

## Task 12: Live screenshot detector

**Files:**
- Create: `Sources/CopyCatKit/ScreenshotDetector.swift`

- [ ] **Step 1: Write the implementation**

`Sources/CopyCatKit/ScreenshotDetector.swift`:

```swift
import Foundation
import CopyCatCore

/// Live folder watcher built on Spotlight. Emits the full newest-first list on
/// every change and separately reports newly-arrived screenshots.
public final class ScreenshotDetector {
    public var onUpdate: (([Screenshot]) -> Void)?
    public var onNewScreenshots: (([Screenshot]) -> Void)?

    private let query = NSMetadataQuery()
    private var knownIDs: Set<String> = []
    private var folderPath: String

    public init(folderPath: String) {
        self.folderPath = folderPath
        NotificationCenter.default.addObserver(
            self, selector: #selector(handle(_:)),
            name: .NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handle(_:)),
            name: .NSMetadataQueryDidUpdate, object: query)
    }

    public func start() {
        query.stop()
        knownIDs = []
        query.searchScopes = [folderPath]
        query.predicate = NSPredicate(
            format: "kMDItemIsScreenCapture == 1 || kMDItemFSName LIKE 'Screenshot*'")
        query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false)]
        query.start()
    }

    public func update(folderPath: String) {
        self.folderPath = folderPath
        start()
    }

    public func stop() { query.stop() }

    @objc private func handle(_ note: Notification) {
        query.disableUpdates()
        defer { query.enableUpdates() }

        var shots: [Screenshot] = []
        for i in 0..<query.resultCount {
            guard let item = query.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
            else { continue }
            let name = item.value(forAttribute: NSMetadataItemFSNameKey) as? String ?? ""
            let flag = item.value(forAttribute: "kMDItemIsScreenCapture") as? Bool
            guard isScreenshot(isScreenCaptureFlag: flag, fileName: name) else { continue }
            let date = (item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date) ?? .distantPast
            shots.append(Screenshot(url: URL(fileURLWithPath: path), captureDate: date))
        }

        let sorted = sortedNewestFirst(shots)
        let fresh = newScreenshots(previousIDs: knownIDs, current: shots)
        knownIDs = Set(shots.map(\.id))

        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(sorted)
            if !fresh.isEmpty { self?.onNewScreenshots?(fresh) }
        }
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/CopyCatKit/ScreenshotDetector.swift
git commit -m "feat: add NSMetadataQuery screenshot detector feeding core diff helpers"
```

---

## Task 13: Fakes + failing AppController tests (TDD red)

Write the fakes and the failing behavior spec for the coordinator **before** implementing it. This is the TDD heart of the app layer: auto-copy on new screenshot, respect the copy toggle, pause when access is lost, and back-fill the newest on resume.

**Files:**
- Create: `Tests/CopyCatKitTests/Fakes.swift`
- Create: `Tests/CopyCatKitTests/AppControllerTests.swift`

- [ ] **Step 1: Write the fakes**

`Tests/CopyCatKitTests/Fakes.swift`:

```swift
import Foundation
@testable import CopyCatKit

final class FakeClipboard: Clipboard, @unchecked Sendable {
    var copied: [URL] = []
    func copyImage(at url: URL) -> Bool { copied.append(url); return true }
}

final class FakePrefs: ScreencapturePreferences, @unchecked Sendable {
    var locationPath: String? = "/tmp/copy-cat-shots"
    var target: String? = "file"
    private(set) var fileTargetEnabled = false
    private(set) var thumbnailDisabled = false
    func enableFileTarget() { fileTargetEnabled = true; target = "file" }
    func disableThumbnail() { thumbnailDisabled = true }
}

final class FakeAccess: FolderAccessing, @unchecked Sendable {
    var readable = true
    func canRead(path: String) -> Bool { readable }
    func saveBookmark(for url: URL) {}
    func resolveBookmark() -> URL? { nil }
    func escapeHatchFolder() -> URL { URL(fileURLWithPath: "/tmp/copy-cat-escape") }
}

/// A SettingsStore backed by a throwaway temp file.
func makeTempStore() -> SettingsStore {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("copy-cat-test-\(UUID().uuidString)")
        .appendingPathComponent("config.json")
    return SettingsStore(url: url)
}
```

- [ ] **Step 2: Write the failing tests**

`Tests/CopyCatKitTests/AppControllerTests.swift`:

```swift
import Foundation
import Testing
import CopyCatCore
@testable import CopyCatKit

private func shot(_ path: String, _ t: TimeInterval = 0) -> Screenshot {
    Screenshot(url: URL(fileURLWithPath: path), captureDate: Date(timeIntervalSince1970: t))
}

@MainActor
private func makeController(clipboard: FakeClipboard, prefs: FakePrefs, access: FakeAccess) -> AppController {
    AppController(store: makeTempStore(), clipboard: clipboard, prefs: prefs, access: access)
}

@Test @MainActor func newScreenshotIsCopiedWhenEnabled() {
    let clip = FakeClipboard()
    let c = makeController(clipboard: clip, prefs: FakePrefs(), access: FakeAccess())
    c.handleNew([shot("/a", 2), shot("/b", 1)])
    #expect(clip.copied == [URL(fileURLWithPath: "/a")]) // newest only
}

@Test @MainActor func newScreenshotIsNotCopiedWhenToggleOff() {
    let clip = FakeClipboard()
    let c = makeController(clipboard: clip, prefs: FakePrefs(), access: FakeAccess())
    var s = c.settings; s.copyOnScreenshot = false; c.updateSettings(s)
    c.handleNew([shot("/a", 2)])
    #expect(clip.copied.isEmpty)
}

@Test @MainActor func autoCopyPausesWithoutAccessAndBackfillsOnResume() {
    let clip = FakeClipboard()
    let access = FakeAccess()
    let c = makeController(clipboard: clip, prefs: FakePrefs(), access: access)

    access.readable = false
    c.refreshStatus()
    #expect(c.status.autoCopyPaused == true)

    c.handleNew([shot("/late", 5)]) // arrives while paused
    #expect(clip.copied.isEmpty)

    access.readable = true
    c.refreshStatus()                // resume -> back-fill
    #expect(clip.copied == [URL(fileURLWithPath: "/late")])
}

@Test @MainActor func clickingATileCopiesIt() {
    let clip = FakeClipboard()
    let c = makeController(clipboard: clip, prefs: FakePrefs(), access: FakeAccess())
    c.copy(shot("/clicked"))
    #expect(clip.copied == [URL(fileURLWithPath: "/clicked")])
}

@Test @MainActor func enableFileTargetFlipsPrefAndClearsBanner() {
    let prefs = FakePrefs()
    prefs.target = "clipboard"
    let c = makeController(clipboard: FakeClipboard(), prefs: prefs, access: FakeAccess())
    c.refreshStatus()
    #expect(c.status.showNotSavingBanner == true)
    c.enableFileTarget()
    #expect(prefs.fileTargetEnabled == true)
    #expect(c.status.showNotSavingBanner == false)
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test --filter AppController`
Expected: FAIL — `AppController` is undefined (compile error). This is the red state.

- [ ] **Step 4: Commit the failing spec**

```bash
git add Tests/CopyCatKitTests/Fakes.swift Tests/CopyCatKitTests/AppControllerTests.swift
git commit -m "test: add AppController behavior spec + fakes (red)"
```

---

## Task 14: AppController implementation (TDD green)

Implement the coordinator to make Task 13's tests pass. Internal methods (`handleNew`, `refreshStatus`, `updateSettings`) are non-private so the test target drives them without a live `NSMetadataQuery`. The real detector is created only in `start()`, which tests never call.

**Files:**
- Create: `Sources/CopyCatKit/AppController.swift`

- [ ] **Step 1: Write the implementation**

`Sources/CopyCatKit/AppController.swift`:

```swift
import SwiftUI
import CopyCatCore

@MainActor
public final class AppController: ObservableObject {
    @Published public private(set) var screenshots: [Screenshot] = []
    @Published public private(set) var status: AppStatus = resolveStatus(
        hasAccess: true, savingToDisk: true, screenshotCount: 0)
    @Published public var settings: Settings

    private let store: SettingsStore
    private let clipboard: Clipboard
    private let prefs: ScreencapturePreferences
    private let access: FolderAccessing
    private var detector: ScreenshotDetector?
    /// Newest screenshot seen while paused, to back-fill on resume.
    private var pendingBackfill: Screenshot?

    public init(
        store: SettingsStore = SettingsStore(),
        clipboard: Clipboard = NSPasteboardClipboard(),
        prefs: ScreencapturePreferences = SystemScreencapturePreferences(),
        access: FolderAccessing = FolderAccess()
    ) {
        self.store = store
        self.clipboard = clipboard
        self.prefs = prefs
        self.access = access
        self.settings = store.load()
    }

    private var home: String { NSHomeDirectory() }

    /// Resolved folder being watched.
    public var watchFolder: String {
        settings.saveLocationPath ?? prefs.resolvedLocation(home: home)
    }

    /// Starts the live detector. Called by the app shell, never by tests.
    public func start() {
        _ = access.resolveBookmark()
        let detector = ScreenshotDetector(folderPath: watchFolder)
        detector.onUpdate = { [weak self] shots in self?.ingest(shots) }
        detector.onNewScreenshots = { [weak self] fresh in self?.handleNew(fresh) }
        self.detector = detector
        detector.start()
        refreshStatus()
    }

    func ingest(_ shots: [Screenshot]) {
        screenshots = shots
        refreshStatus()
    }

    func handleNew(_ fresh: [Screenshot]) {
        guard settings.copyOnScreenshot, let newest = fresh.first else { return }
        if status.autoCopyPaused {
            pendingBackfill = newest
        } else {
            clipboard.copyImage(at: newest.url)
        }
    }

    func refreshStatus() {
        let hasAccess = access.canRead(path: watchFolder)
        let wasPaused = status.autoCopyPaused
        status = resolveStatus(
            hasAccess: hasAccess,
            savingToDisk: prefs.isSavingToDisk,
            screenshotCount: screenshots.count
        )
        if wasPaused && !status.autoCopyPaused, settings.copyOnScreenshot,
           let backfill = pendingBackfill ?? screenshots.first {
            clipboard.copyImage(at: backfill.url)
            pendingBackfill = nil
        }
    }

    // MARK: User actions

    public func copy(_ shot: Screenshot) { clipboard.copyImage(at: shot.url) }

    public func updateSettings(_ newSettings: Settings) {
        let old = settings
        settings = newSettings.clamped()
        try? store.save(settings)
        if settings.saveLocationPath != old.saveLocationPath {
            detector?.update(folderPath: watchFolder)
        }
        refreshStatus()
    }

    public func enableFileTarget() { prefs.enableFileTarget(); refreshStatus() }
    public func disableThumbnail() { prefs.disableThumbnail() }

    public func chooseFolder(_ url: URL) {
        access.saveBookmark(for: url)
        var s = settings
        s.saveLocationPath = url.path
        updateSettings(s)
    }

    public func useEscapeHatch() {
        let url = access.escapeHatchFolder()
        var s = settings
        s.saveLocationPath = url.path
        updateSettings(s)
    }

    public func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")!
        NSWorkspace.shared.open(url)
    }

    public func revealInFinder(_ shot: Screenshot) {
        NSWorkspace.shared.activateFileViewerSelecting([shot.url])
    }

    public func copyPath(_ shot: Screenshot) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(shot.url.path, forType: .string)
    }
}
```

- [ ] **Step 2: Run the tests to verify they pass**

Run: `swift test --filter AppController`
Expected: PASS (all five tests). Green.

- [ ] **Step 3: Run the full suite**

Run: `swift test`
Expected: All `CopyCatCoreTests` + `CopyCatKitTests` PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/CopyCatKit/AppController.swift
git commit -m "feat: implement AppController coordinator (auto-copy, pause, back-fill) — tests green"
```

---

## Task 15: Menu bar entry point (status item + popover)

Replace the placeholder `runApp()` with the real bootstrap, add the `AppDelegate` (status item + popover + black-cat badge), and a minimal `PopoverRootView` (fleshed out in Task 20).

**Files:**
- Modify: `Sources/CopyCatKit/Bootstrap.swift`
- Create: `Sources/CopyCatKit/AppDelegate.swift`
- Create: `Sources/CopyCatKit/PopoverRootView.swift`

- [ ] **Step 1: Rewrite `Bootstrap.swift`**

`Sources/CopyCatKit/Bootstrap.swift`:

```swift
import AppKit

private var sharedDelegate: AppDelegate?

/// Boots the menu bar app. Retains the delegate for the process lifetime.
public func runApp() {
    let delegate = AppDelegate()
    sharedDelegate = delegate
    let app = NSApplication.shared
    app.delegate = delegate
    app.setActivationPolicy(.accessory) // no Dock icon (belt-and-suspenders for LSUIElement)
    app.run()
}
```

- [ ] **Step 2: Write `AppDelegate.swift`**

`Sources/CopyCatKit/AppDelegate.swift`:

```swift
import AppKit
import SwiftUI
import CopyCatCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let controller = AppController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        updateBadge()

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 720, height: 460)
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView().environmentObject(controller))
    }

    private func updateBadge() {
        guard let button = statusItem.button else { return }
        let name = badgeSymbolName(for: controller.status.content)
        button.image = NSImage(systemSymbolName: name, accessibilityDescription: "copy-cat")
        button.image?.isTemplate = true
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            controller.refreshStatus()
            updateBadge()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
```

- [ ] **Step 3: Write a minimal `PopoverRootView.swift`**

`Sources/CopyCatKit/PopoverRootView.swift`:

```swift
import SwiftUI
import CopyCatCore

struct PopoverRootView: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        Text("copy-cat — \(controller.screenshots.count) screenshots")
            .frame(width: 720, height: 460)
    }
}
```

- [ ] **Step 4: Build and run; verify the menu bar item appears**

Run:
```bash
swift build
swift run CopyCat &
sleep 3
```
Expected: a black-cat (`cat.fill`) icon appears in the menu bar. Clicking it opens a 720×460 popover showing the screenshot count. No Dock icon.
Stop it: `kill %1`.

- [ ] **Step 5: Commit**

```bash
git add Sources/CopyCatKit/Bootstrap.swift Sources/CopyCatKit/AppDelegate.swift Sources/CopyCatKit/PopoverRootView.swift
git commit -m "feat: add menu bar status item + popover shell with black-cat badge"
```

---

## Task 16: Thumbnail loader + grid view

**Files:**
- Create: `Sources/CopyCatKit/ScreenshotThumbnail.swift`
- Create: `Sources/CopyCatKit/GridView.swift`

- [ ] **Step 1: Write `ScreenshotThumbnail.swift`**

`Sources/CopyCatKit/ScreenshotThumbnail.swift`:

```swift
import SwiftUI

/// Loads an NSImage off the main thread and renders it with a given content mode.
struct ScreenshotImage: View {
    let url: URL
    var contentMode: ContentMode = .fill

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .task(id: url) {
            let loaded = await Self.load(url)
            await MainActor.run { self.image = loaded }
        }
    }

    private static func load(_ url: URL) async -> NSImage? {
        await Task.detached(priority: .userInitiated) {
            NSImage(contentsOf: url)
        }.value
    }
}
```

- [ ] **Step 2: Write `GridView.swift`**

`Sources/CopyCatKit/GridView.swift`:

```swift
import SwiftUI
import CopyCatCore

struct GridView: View {
    let screenshots: [Screenshot]
    let columns: Int
    let maxRows: Int
    let tileSize: CGFloat
    let spacing: CGFloat
    let onHover: (Screenshot?) -> Void
    let onClick: (Screenshot) -> Void

    private var layout: GridLayout {
        gridLayout(itemCount: screenshots.count, columns: columns, maxRows: maxRows)
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(tileSize), spacing: spacing, alignment: .topLeading),
              count: layout.columns)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: layout.needsScroll) {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: spacing) {
                ForEach(screenshots) { shot in
                    ScreenshotImage(url: shot.url, contentMode: .fill)
                        .frame(width: tileSize, height: tileSize)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                        .onHover { inside in onHover(inside ? shot : nil) }
                        .onTapGesture { onClick(shot) }
                }
            }
            .padding(spacing)
        }
        .frame(
            width: CGFloat(layout.columns) * tileSize + CGFloat(layout.columns + 1) * spacing,
            height: CGFloat(layout.visibleRows) * tileSize + CGFloat(layout.visibleRows + 1) * spacing
        )
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/CopyCatKit/ScreenshotThumbnail.swift Sources/CopyCatKit/GridView.swift
git commit -m "feat: add async thumbnail loader + aspect-fill grid view"
```

---

## Task 17: Preview pane + info panel

**Files:**
- Create: `Sources/CopyCatKit/PreviewPane.swift`

- [ ] **Step 1: Write `PreviewPane.swift`**

`Sources/CopyCatKit/PreviewPane.swift`:

```swift
import SwiftUI
import CopyCatCore

struct PreviewPane: View {
    let screenshot: Screenshot?
    let onReveal: (Screenshot) -> Void
    let onCopyPath: (Screenshot) -> Void
    let onCopyImage: (Screenshot) -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let shot = screenshot {
                ScreenshotImage(url: shot.url, contentMode: .fit)
                    .frame(maxWidth: 320, maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 8) {
                    Text(Self.dateFormatter.string(from: shot.captureDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button("Open in Finder") { onReveal(shot) }
                        Button("Copy path") { onCopyPath(shot) }
                        Button("Copy image") { onCopyImage(shot) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Rectangle().fill(.quaternary)
                    .frame(maxWidth: 320, maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
        }
        .frame(width: 340)
        .padding(12)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/CopyCatKit/PreviewPane.swift
git commit -m "feat: add preview pane with native-aspect preview + info actions"
```

---

## Task 18: State views (empty, no-access, not-saving banner)

**Files:**
- Create: `Sources/CopyCatKit/StateViews.swift`

- [ ] **Step 1: Write `StateViews.swift`**

`Sources/CopyCatKit/StateViews.swift`:

```swift
import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "cat").font(.largeTitle).foregroundStyle(.secondary)
            Text("No screenshots yet.").font(.headline)
            Text("Press ⌘⇧3 or ⌘⇧4 to take one.").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NotSavingBanner: View {
    let onEnable: () -> Void
    let onDisableThumbnail: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text("Screenshots aren't being saved to disk.").font(.callout)
            Spacer()
            Button("Enable", action: onEnable).buttonStyle(.borderedProminent).controlSize(.small)
            Button("Hide thumbnail", action: onDisableThumbnail).buttonStyle(.bordered).controlSize(.small)
        }
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
            Text("Can't see your screenshots").font(.headline)
            Text("copy-cat needs permission to read your screenshot folder.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
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
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/CopyCatKit/StateViews.swift
git commit -m "feat: add empty / no-access / not-saving state views"
```

---

## Task 19: Settings sheet (cog)

**Files:**
- Create: `Sources/CopyCatKit/SettingsView.swift`

- [ ] **Step 1: Write `SettingsView.swift`**

`Sources/CopyCatKit/SettingsView.swift`:

```swift
import SwiftUI
import AppKit
import CopyCatCore

struct SettingsView: View {
    @EnvironmentObject var controller: AppController
    @Binding var isPresented: Bool

    @State private var draft: Settings = .defaults

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
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/CopyCatKit/SettingsView.swift
git commit -m "feat: add settings sheet (copy toggle, save location, grid size)"
```

---

## Task 20: Assemble the full popover layout

Replace the placeholder `PopoverRootView` with the real preview-left / grid-right layout, banner, state switch, and a cog opening settings. Uses the `previewTarget` core helper from Task 8.

**Files:**
- Modify: `Sources/CopyCatKit/PopoverRootView.swift`

- [ ] **Step 1: Replace `PopoverRootView.swift`**

`Sources/CopyCatKit/PopoverRootView.swift`:

```swift
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
```

- [ ] **Step 2: Build and run; verify the full UI end-to-end**

Run:
```bash
swift build
swift run CopyCat &
sleep 3
```
Then, per `~/.claude/docs/testing.md`, verify by observation:
- Click the menu bar cat → popover opens with preview (left) + grid (right).
- Take a screenshot (⌘⇧4) → it appears top-left in the grid, and the image is on the clipboard (paste into Preview/Notes to confirm).
- Hover a tile → preview shows it at native aspect ratio; default preview is the newest.
- Click a tile → that image copies (paste to confirm).
- Open the cog → change columns/rows → grid reflows.
Stop the app: `kill %1`.

- [ ] **Step 3: Commit**

```bash
git add Sources/CopyCatKit/PopoverRootView.swift
git commit -m "feat: assemble full popover (preview+grid, banner, states, settings cog)"
```

---

## Task 21: UI structure tests (ViewInspector)

Add a thin layer of SwiftUI structure tests for the static state views — assert the right copy and buttons render. Branch-selection logic is already covered by the `AppStatus` tests; this guards the view content itself. Visual/interactive behavior (hover, popover, clipboard paste, NSOpenPanel) stays manual.

**Files:**
- Modify: `Package.swift`
- Create: `Tests/CopyCatKitTests/UIStructureTests.swift`

- [ ] **Step 1: Add the ViewInspector dependency to `Package.swift`**

Replace `Package.swift` with:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CopyCat",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0"),
    ],
    targets: [
        .target(name: "CopyCatCore"),
        .target(name: "CopyCatKit", dependencies: ["CopyCatCore"]),
        .executableTarget(name: "CopyCat", dependencies: ["CopyCatKit"]),
        .testTarget(name: "CopyCatCoreTests", dependencies: ["CopyCatCore"]),
        .testTarget(
            name: "CopyCatKitTests",
            dependencies: ["CopyCatKit", "ViewInspector"]
        ),
    ]
)
```

- [ ] **Step 2: Write the failing test**

`Tests/CopyCatKitTests/UIStructureTests.swift`:

```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import CopyCatKit

final class UIStructureTests: XCTestCase {
    func testEmptyStateShowsPrompt() throws {
        let view = EmptyStateView()
        XCTAssertNoThrow(try view.inspect().find(text: "No screenshots yet."))
        XCTAssertNoThrow(try view.inspect().find(text: "Press ⌘⇧3 or ⌘⇧4 to take one."))
    }

    func testNoAccessOffersThreeRecoveryButtons() throws {
        var tapped: [String] = []
        let view = NoAccessView(
            onChooseFolder: { tapped.append("choose") },
            onUseEscapeHatch: { tapped.append("escape") },
            onOpenSettings: { tapped.append("settings") })
        XCTAssertNoThrow(try view.inspect().find(button: "Choose folder…"))
        XCTAssertNoThrow(try view.inspect().find(button: "Use a folder that needs no permission"))
        XCTAssertNoThrow(try view.inspect().find(button: "Open System Settings"))
    }
}
```

- [ ] **Step 3: Run the test to verify it fails first, then passes**

Run: `swift test --filter UIStructureTests`
Expected: First run may FAIL to resolve until the package fetches ViewInspector. After resolution, the tests PASS (the views from Tasks 18 already render this copy). If a `find(button:)` throws, fix the view's button title to match — the test is the source of truth for the visible string.

- [ ] **Step 4: Run the full suite**

Run: `swift test`
Expected: All tests across both test targets PASS.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Tests/CopyCatKitTests/UIStructureTests.swift
git commit -m "test: add ViewInspector structure tests for empty/no-access views"
```

---

## Task 22: App bundle script (.app + LSUIElement Info.plist)

**Files:**
- Create: `Resources/Info.plist.template`
- Create: `scripts/bundle.sh`

- [ ] **Step 1: Write `Resources/Info.plist.template`**

`Resources/Info.plist.template`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>copy-cat</string>
    <key>CFBundleDisplayName</key><string>copy-cat</string>
    <key>CFBundleIdentifier</key><string>com.0x63616c.copy-cat</string>
    <key>CFBundleExecutable</key><string>CopyCat</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>© 2026 0x63616c</string>
</dict>
</plist>
```

- [ ] **Step 2: Write `scripts/bundle.sh`**

`scripts/bundle.sh`:

```bash
#!/bin/bash
# Build CopyCat in release and assemble a CopyCat.app bundle (menu bar agent).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${ROOT}/CopyCat.app"
EXE_NAME="CopyCat"

echo "==> Building release"
swift build -c release --package-path "$ROOT"
BIN="$(swift build -c release --package-path "$ROOT" --show-bin-path)/${EXE_NAME}"

echo "==> Assembling ${APP}"
rm -rf "$APP"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "$BIN" "${APP}/Contents/MacOS/${EXE_NAME}"
cp "${ROOT}/Resources/Info.plist.template" "${APP}/Contents/Info.plist"

echo "==> Built ${APP}"
```

- [ ] **Step 3: Make it executable and run it**

Run:
```bash
chmod +x scripts/bundle.sh
./scripts/bundle.sh
open CopyCat.app
sleep 3
```
Expected: `CopyCat.app` is created; opening it shows the black-cat menu bar icon, no Dock icon. Quit via the menu bar / `fkill`.

- [ ] **Step 4: Commit**

```bash
git add Resources/Info.plist.template scripts/bundle.sh
git commit -m "build: add .app bundling script with LSUIElement Info.plist"
```

---

## Task 23: Sign + notarize script, and docs

Codesigning needs a Developer ID Application certificate and notarytool credentials; the script is complete but its successful run depends on those being present. Documented, not hardcoded.

**Files:**
- Create: `scripts/sign-notarize.sh`
- Modify: `README.md`

- [ ] **Step 1: Write `scripts/sign-notarize.sh`**

`scripts/sign-notarize.sh`:

```bash
#!/bin/bash
# Sign + notarize CopyCat.app for direct download (Developer ID).
# Requires:
#   - A "Developer ID Application: ..." cert in the login keychain.
#   - A stored notarytool keychain profile (see comment below).
# Env:
#   SIGN_IDENTITY  e.g. "Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE notarytool keychain profile name
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${ROOT}/CopyCat.app"
ZIP="${ROOT}/CopyCat.zip"

: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your stored notarytool profile}"

# One-time profile setup (run manually, not here):
#   xcrun notarytool store-credentials "$NOTARY_PROFILE" \
#     --apple-id you@example.com --team-id TEAMID --password APP_SPECIFIC_PW

echo "==> Codesigning"
codesign --force --options runtime --timestamp \
  --sign "$SIGN_IDENTITY" "$APP"

echo "==> Zipping for notarization"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting to notary service"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling"
xcrun stapler staple "$APP"

echo "==> Verifying"
spctl -a -vv -t install "$APP"
echo "==> Done: signed + notarized ${APP}"
```

- [ ] **Step 2: Make it executable and verify the codesign step**

Run:
```bash
chmod +x scripts/sign-notarize.sh
codesign --force --deep --sign - CopyCat.app && codesign -dv CopyCat.app 2>&1 | head -5
```
Expected: ad-hoc signing (`-`) succeeds, proving the bundle structure is signable. Full Developer ID signing/notarization runs only when `SIGN_IDENTITY` + `NOTARY_PROFILE` are configured.

- [ ] **Step 3: Rewrite `README.md` for the native app**

`README.md`:

```markdown
# copy-cat

A macOS menu bar app that auto-copies every new screenshot to the clipboard and
gives you a quick-access grid of recent screenshots. The file still saves to disk.

## Build

```bash
swift build            # debug build
swift test             # run the CopyCatCore + CopyCatKit test suites
./scripts/bundle.sh    # produce CopyCat.app (menu bar agent, no Dock icon)
open CopyCat.app
```

## Distribute (Developer ID)

```bash
export SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="copy-cat-notary"
./scripts/sign-notarize.sh
```

## How it works

- Watches your screenshot folder with `NSMetadataQuery`, identifying screenshots
  by the Spotlight `kMDItemIsScreenCapture` flag (filename fallback if indexing
  is off).
- On each new screenshot, copies the image to the clipboard (if enabled).
- Reads — never relocates — screenshots where macOS already saves them.
- App state lives in `~/Library/Application Support/copy-cat/`.

## Architecture

- `CopyCatCore` — pure logic, no AppKit, fully unit-tested.
- `CopyCatKit` — AppKit/SwiftUI coordinator + views (AppController is TDD'd via fakes).
- `CopyCat` — executable shim (`runApp()`).

See `SPEC.md` for the full product spec.
```

- [ ] **Step 4: Final full test + build gate**

Run:
```bash
swift test && ./scripts/bundle.sh
```
Expected: all tests PASS and `CopyCat.app` builds.

- [ ] **Step 5: Commit**

```bash
git add scripts/sign-notarize.sh README.md
git commit -m "build: add sign+notarize script; rewrite README for native app"
```

---

## Task 24: Cleanup — remove the legacy shell implementation

**Files:**
- Delete: `install.sh`, `uninstall.sh`, `screenshot-to-clipboard.sh`, `watch_2026*` stray logs

- [ ] **Step 1: Confirm these are the legacy artifacts**

Run: `ls install.sh uninstall.sh screenshot-to-clipboard.sh watch_* 2>/dev/null`
Expected: lists the legacy shell installer, uninstaller, helper, and stray `watch_*` log files. (If any are still wanted, skip them.)

- [ ] **Step 2: Remove them**

```bash
git rm install.sh uninstall.sh screenshot-to-clipboard.sh
rm -f watch_2026*
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove legacy shell/launchd implementation (superseded by native app)"
```

---

## Self-Review

**Spec coverage:**
- Auto-copy on new screenshot → Task 12 (detect) + Task 14 (`handleNew` copies newest), tested in Task 13.
- Menu bar agent, no Dock → Task 15 (`.accessory`) + Task 22 (`LSUIElement`).
- `kMDItemIsScreenCapture` detection + filename fallback → Task 6 + Task 12 predicate.
- One mechanism for detection/trigger/feed → Task 12 (`onUpdate` feeds grid, `onNewScreenshots` triggers copy).
- Grid rules → Task 3 (math) + Task 16 (view) + Task 20 (wiring).
- Preview (hover larger native-aspect, default newest, info actions) → Task 8 (`previewTarget`) + Task 17 + Task 20.
- Settings → Task 5 (model) + Task 19 (UI).
- States + recovery routes + badge + pause/back-fill → Task 4 (reducer) + Task 8 (badge) + Task 13/14 (pause/back-fill, tested) + Task 15 (badge) + Task 18 (views).
- Does not relocate; reads in place; escape-hatch; bookmark consent → Task 11 + Task 14.
- App state under Application Support → Task 5 + Task 11.
- Swift + SwiftUI/AppKit, NSStatusItem/LSUIElement/NSPopover/NSMetadataQuery → Tasks 12, 15, 22.
- Signed + notarized Developer ID → Task 23.
- Black-cat menu bar icon → Task 8 (`badgeSymbolName` → `cat.fill`) + Task 15.
- Out of scope items → none implemented. ✓

**TDD coverage:** All `CopyCatCore` logic (Tasks 2–8) is strict red→green. `AppController` auto-copy/pause/back-fill behavior is TDD'd with fakes (Tasks 13→14). Static state views get ViewInspector structure tests (Task 21). Thin system wrappers (Tasks 9–12) and the interactive shell/views (Tasks 15–20) are build- + run-verified, which is the appropriate bar for adapters over Apple frameworks and live UI.

**Placeholder scan:** Every code step contains complete, compilable code. The only credential-gated step is Developer ID signing/notarization (Task 23), with an ad-hoc sign check to verify bundle structure.

**Type consistency:** `Screenshot` (id=path); `gridLayout`/`GridLayout`; `resolveStatus`/`AppStatus`/`ContentState`; `Settings`/`SettingsStore`; `isScreenshot`/`sortedNewestFirst`/`newScreenshots`; `isProtectedLocation`/`savingToDisk`; `previewTarget`/`badgeSymbolName`; `Clipboard.copyImage(at:)`; `ScreencapturePreferences` (`locationPath`/`target`/`enableFileTarget`/`disableThumbnail`/`isSavingToDisk`); `FolderAccessing` (`canRead`/`saveBookmark`/`resolveBookmark`/`escapeHatchFolder`); `ScreenshotDetector` (`onUpdate`/`onNewScreenshots`/`start`/`update(folderPath:)`); `AppController` API (`handleNew`/`refreshStatus`/`updateSettings`/`copy`/`enableFileTarget`/`chooseFolder`/`useEscapeHatch`); `runApp()`; view names (`ScreenshotImage`, `GridView`, `PreviewPane`, `EmptyStateView`/`NotSavingBanner`/`NoAccessView`, `SettingsView`, `PopoverRootView`) — all consistent across tasks and across the `CopyCatCore`/`CopyCatKit` split. ✓

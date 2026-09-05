# Architecture

CopyCat is a Swift Package with a minimal executable shim and two modules. It requires macOS 14 or later.

## Data flow

`runApp()` → `AppDelegate` → `AppController` → `ScreenshotDetector` → screenshot array and clipboard actions.

The detector combines a direct filesystem watch with periodic directory scans and identifies screenshots by recognized filename patterns. New captures flow to `AppController.handleNew`; copying respects the automatic-copy preference and folder-access/screenshot-destination state. The UI renders the controller’s published state. The originals are read, never moved or deleted.

## Module boundaries

- **CopyCatCore:** codable settings, screenshot values, detection and status rules, grid calculations, shortcut values, logging, and the source release version. Keep system UI out of this module.
- **CopyCatKit:** AppKit shell, SwiftUI views, clipboard and folder adapters, global hotkeys, thumbnail cache, and login-item service. `AppController` coordinates application behavior; the shell owns popover lifecycle and modal folder selection.
- **CopyCat:** calls `runApp()`.

`LoginItem` reads the system-owned `SMAppService` status. It never persists a duplicate Boolean. Its closures allow deterministic state-transition tests without registering the test runner. The settings view refreshes on appearance and app activation, and reports registration errors or required approval.

`PopoverMetrics` owns shared app/view dimensions. `ThumbnailCache` downsamples images rather than decoding full-size screenshots for every grid tile. Tests render authentic product screenshots only when explicitly enabled.

## Persistence and privacy

Settings and bookmarks live under `~/Library/Application Support/copy-cat/`. `AppLog` writes a bounded local activity log there; it may include screenshot names and paths. The app has no account, analytics, or cloud image transfer. Sparkle fetches update metadata and archives from GitHub over HTTPS; system profiling is disabled. Automatic checks can be turned off in Settings. The website uses no scripts, external fonts, trackers, or forms; GitHub still operates the hosting and download infrastructure.

## Versioning and distribution

`CopyCatCore.version` is the source of truth. `bundle.sh` stamps `CFBundleShortVersionString` and `CFBundleVersion`, includes resources, and signs the bundle. Runtime version display reads only the CopyCat app bundle, falling back to a development version for bare executables and test hosts. See [releases](releases.md).

## Appearance

Glass is reserved for navigation controls and the pinned Settings footer. On macOS 26, these use native `glassEffect`; macOS 14/15 use regular materials. The app follows system light/dark appearance and honors Reduce Transparency; the SwiftUI pane transition honors Reduce Motion. The original screenshot imagery is never tinted with glass. Build with Xcode 26.2+ to include the native glass path.

## Updates

`UpdateManager` wraps Sparkle’s standard updater controller. It starts only from the real CopyCat app bundle, after app launch. Sparkle owns scheduling, installation, and persisted update settings; Combine observes its KVO properties for UI state. The app requires both signed appcasts and archive signature verification before extraction. The public Ed25519 key is embedded in Info.plist; the dedicated private key is stored in the maintainer’s Keychain and GitHub Actions secret, never in Git.

`CFBundleVersion` follows the source semantic version so local and CI builds compare consistently for updates. `CopyCatBuildNumber` stores the informational build number shown in Settings. Sparkle is embedded under `Contents/Frameworks`, with a relative executable runpath; nested code is signed inside out.

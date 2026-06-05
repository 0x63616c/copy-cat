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

Dev loop — rebuild and relaunch the running menu bar app in one step:

```bash
./scripts/dev.sh           # debug build -> refresh bundle -> relaunch
./scripts/dev.sh --release # same, with the release binary
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

## Popover

Clicking the black-cat menu bar icon opens a popover: preview on the left,
square-tile grid of recent screenshots on the right (newest top-left). Click a
tile to copy it. The cog opens settings (copy-on-screenshot toggle, save
location, grid size). Recovery states handle "not saving to disk" and "no folder
access".

## Architecture

- `CopyCatCore` — pure logic, no AppKit, fully unit-tested.
- `CopyCatKit` — AppKit/SwiftUI coordinator + views (`AppController` is TDD'd via fakes).
- `CopyCat` — executable shim (`runApp()`).

See `SPEC.md` for the full product spec and
`docs/superpowers/plans/2026-06-04-copy-cat-menu-bar-app.md` for the build plan.

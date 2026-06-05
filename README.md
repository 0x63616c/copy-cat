# copy-cat

A macOS menu bar app that auto-copies every new screenshot to the clipboard and
gives you a quick-access grid of recent screenshots. The file still saves to disk.

## Install (build it yourself)

There's no prebuilt download yet, so you install copy-cat by building it from
source. It's a two-minute process on a Mac with the developer tools.

### Requirements

- **macOS 14 (Sonoma) or newer** — the app sets `LSMinimumSystemVersion` to 14.0.
- **Xcode Command Line Tools** (ships the Swift 6 toolchain). Install with:
  ```bash
  xcode-select --install
  ```
  Verify you have Swift 6+:
  ```bash
  swift --version   # expect "Apple Swift version 6.x"
  ```
- Works on both Apple Silicon and Intel — `swift build` compiles a native
  binary for whichever Mac you build on.

### Steps

```bash
# 1. Get the source
git clone https://github.com/0x63616c/copy-cat.git
cd copy-cat

# 2. (optional) sanity-check the build and tests
swift build            # debug build
swift test             # 37 tests across CopyCatCore + CopyCatKit

# 3. Produce the app bundle (release build, menu bar agent, no Dock icon)
./scripts/bundle.sh    # writes ./CopyCat.app

# 4. Install it
cp -R CopyCat.app /Applications/
open /Applications/CopyCat.app
```

`bundle.sh` ad-hoc signs the bundle, so a copy you build on your own Mac opens
without any Gatekeeper warning. (Ad-hoc signing only works on the machine that
built it — to hand the `.app` to someone else, notarize it; see
[Distribute](#distribute-developer-id) below.)

### First run

copy-cat lives in the menu bar (look for the black-cat icon, top-right) — it has
no Dock icon or window by default. On first launch:

1. Click the cat icon to open the popover.
2. macOS will prompt for access to the folder where your screenshots are saved
   (the Desktop by default). Grant it so copy-cat can read new screenshots.
3. Take a screenshot (`⌘⇧4`) — it's copied to your clipboard automatically and
   appears in the grid.

To launch copy-cat automatically at login, add it under **System Settings →
General → Login Items**.

## Build (development)

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

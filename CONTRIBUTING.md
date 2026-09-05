# Contributing to CopyCat

Small, focused improvements are welcome. Open an issue before a large redesign so we can agree on the user problem and scope. Be kind, explain your reasoning, and respect other contributors’ time.

## Get running

Use macOS 14+ and a Swift 6+ toolchain. Clone the repository, run `swift test`, then `./scripts/dev.sh`. No package manager setup beyond Swift Package Manager is required. ViewInspector is used only by tests.

## Make a change

1. Create a branch and keep the change focused.
2. Keep pure logic in `CopyCatCore`, platform integration and views in `CopyCatKit`.
3. Add behavior tests for meaningful logic. Use injected fakes for clipboard, folder access, and login-item registration; tests must not change real system preferences.
4. Run `swift test`, `./scripts/bundle.sh`, and `python3 scripts/check-site.py` when the website changes.
5. Open a pull request describing the problem, resulting behavior, and validation. Include safe screenshots for UI changes.

Ordinary tests do not regenerate product images. To intentionally refresh them, run `COPYCAT_SCREENSHOTS=1 COPYCAT_SCREEN_CAPTURE=1 swift test --filter RenderSnapshots` on a Mac with a graphical session and Screen Recording permission for the terminal, inspect `site/assets/library.png` and `site/assets/settings.png`, and commit the images with the relevant UI change. These render actual app views with synthetic data, not personal screenshots.

## Issue tracking

Public reports and discussions use GitHub Issues. Maintainer/agent implementation tracking uses Beads (`bd prime`, then `bd ready`). Beads is not required to build or contribute a pull request. Its database sync is separate from code: `bd dolt push/pull`, never a routine JSONL import.

## Privacy and reporting

The app log can contain screenshot filenames and local folder paths. Redact logs before posting. Do not upload personal screenshots or credentials. See [SECURITY.md](SECURITY.md) for private vulnerability reports.

By contributing, you agree that your contribution is provided under the repository’s MIT license.

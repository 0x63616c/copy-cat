# Installing CopyCat

## Download and open

1. Get `CopyCat-macOS.zip` from the [latest GitHub release](https://github.com/0x63616c/copy-cat/releases/latest).
2. Unzip it and move **CopyCat.app** to **Applications**.
3. Open the app. It appears in the menu bar, with no Dock icon.
4. Grant access to your screenshot folder if macOS asks. Take a screenshot to check automatic copying.
5. Open CopyCat’s Settings and enable **Open at Login** to start it when you sign in.

Requires macOS 14+. Universal downloads support Apple Silicon and Intel.

## If macOS blocks the first launch

Current CI downloads are **ad-hoc signed, not Apple-notarized**. After attempting to open a trusted release, go to **System Settings → Privacy & Security → Open Anyway**, and confirm the prompt. Follow [Apple’s guide](https://support.apple.com/en-us/102445). Organization policies may prohibit this; use an approved build or build from source instead. Do not disable Gatekeeper globally.

To verify the downloaded ZIP, download `SHA256SUMS.txt` into the same folder and run:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

## Open at Login

CopyCat uses Apple’s `SMAppService.mainApp`, rather than a separate background helper. The setting reflects macOS’s actual registration status. If approval is needed, use **Open Login Items…** and allow CopyCat under **System Settings → General → Login Items & Extensions**. CopyCat refreshes the status when you return.

Install in Applications before enabling startup. Move or replace the app only after quitting it. If you move it later and startup stops working, open the installed copy and toggle Open at Login off and on. The app starts when you log in to your account, not before the login screen.

## Updating

Download the latest ZIP, quit CopyCat using the button at the bottom of Settings, and replace the copy in Applications. Reopen it. Your saved settings remain in `~/Library/Application Support/copy-cat/`. The version and build number are pinned at the bottom of Settings. Or use **Settings → Updates → Check for Updates…**. Under **Updates**, automatic checks are on by default (daily); enable **Install updates automatically** to download in the background and install when you quit. Sparkle validates signed update metadata and archives before installation. If authorization is needed, it asks you. Update preferences are stored by Sparkle in macOS user defaults, separately from CopyCat’s JSON settings.

## Troubleshooting

- **No Dock icon:** expected. Look for the cat in the menu bar.
- **Two cats:** quit the installed and development copies, then open only the intended bundle.
- **No screenshots:** check Settings → Library → Watch folder. The app recognizes screenshot filename patterns in the watched folder.
- **Not copying:** enable Copy on screenshot, grant folder access, and make sure macOS saves screenshots to files. A recovery banner appears if the screenshot destination is clipboard-only.
- **Default hotkeys are awkward:** HYPR means Control + Option + Shift + Command. Click a shortcut in Settings to record another combination.
- **Need diagnostic details:** Settings → Diagnostics → Open Logs. Logs may contain personal paths and filenames; redact before sharing.

## Uninstalling

Turn off Open at Login, quit CopyCat, and move the app to Trash. If you also want to discard its preferences, remove `~/Library/Application Support/copy-cat/`. Your original screenshots are untouched.

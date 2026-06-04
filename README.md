# copy-cat

macOS screenshots that go **both** places at once: **saved** to a folder (historical record) **and** **copied** to the clipboard.

macOS only lets you pick one. copy-cat bridges it with a launchd agent that watches the folder and copies each new screenshot to the clipboard. No app, no extra permissions, no rebound shortcuts.

## Install (one line, any Mac)

```bash
curl -fsSL https://raw.githubusercontent.com/0x63616c/copy-cat/main/install.sh | bash
```

Or from a clone:

```bash
./install.sh     # set up
./uninstall.sh   # revert (leaves your screenshots alone)
```

Test: Cmd+Shift+4, grab a region, then Cmd+V.

## Notes

- **The installer detects where your screenshots already save** (`defaults read com.apple.screencapture location`) instead of guessing:
  - Already outside the protected zone (e.g. `~/Pictures/Screenshots`) → watched as-is, nothing moved.
  - A dedicated folder in a protected zone (e.g. `~/Desktop/Screenshots`) → migrated to `~/Screenshots` with a symlink left behind so it still shows on your Desktop.
  - The bare Desktop (macOS default) → future screenshots repointed to `~/Screenshots`; existing Desktop files untouched.
- **Why it can't stay on the Desktop:** Desktop/Documents/Downloads are TCC-protected. A launchd background agent is denied read access (`Operation not permitted`) without Full Disk Access, which isn't portable. `~/Screenshots` is outside that zone. The helper reads the live `location` setting at runtime, so it always watches wherever screenshots actually go.
- Disables the floating screenshot thumbnail (it delays writing the file to disk, which lagged the clipboard copy). `uninstall.sh` turns it back on.
- Agent activity is logged to `~/.local/state/screenshot-clipboard.log` for debugging.

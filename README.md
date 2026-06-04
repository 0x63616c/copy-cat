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

- **Screenshots live in `~/Screenshots`, shown on your Desktop as a `Screenshots` alias.** The Desktop is a TCC-protected folder, and a launchd background agent is denied read access to it (`Operation not permitted`) without Full Disk Access, which isn't portable. `~/Screenshots` is outside that zone, so the agent can read new captures. The Desktop symlink keeps them visible where you expect.
- Disables the floating screenshot thumbnail (it delays writing the file to disk, which lagged the clipboard copy). `uninstall.sh` turns it back on.
- Agent activity is logged to `~/.local/state/screenshot-clipboard.log` for debugging.

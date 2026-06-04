# copy-cat

macOS screenshots that go **both** places at once: **saved** to `~/Desktop/Screenshots` (historical record) **and** **copied** to the clipboard.

macOS only lets you pick one. copy-cat bridges it with a launchd agent that watches the folder and copies each new screenshot to the clipboard. No app, no extra permissions, no rebound shortcuts.

## Use

```bash
./install.sh     # set up (run on each laptop)
./uninstall.sh   # revert (leaves your screenshots alone)
```

Test: Cmd+Shift+4, grab a region, then Cmd+V.

> Disables the floating screenshot thumbnail (it delays writing the file to disk, which lagged the clipboard copy). `uninstall.sh` turns it back on.

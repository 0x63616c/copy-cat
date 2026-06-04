#!/bin/bash
# copy-cat installer.
# macOS screenshots -> saved to ~/Screenshots (historical record, aliased on the Desktop)
#                   -> AND copied to the clipboard automatically.
# Portable across machines: no third-party app, no extra permissions.
#
# Why ~/Screenshots and not ~/Desktop/Screenshots?
# The Desktop is a TCC-protected folder. A launchd background agent is denied
# read access to it ("Operation not permitted") unless granted Full Disk Access,
# which isn't portable and can't be granted cleanly to a shell script. ~/Screenshots
# lives outside the protected zone, so the agent can read new screenshots. We drop a
# symlink at ~/Desktop/Screenshots so it still shows up on your Desktop.

set -euo pipefail

LABEL="com.0x63616c.screenshot-clipboard"
WATCH_DIR="${HOME}/Screenshots"
DESKTOP_LINK="${HOME}/Desktop/Screenshots"
BIN_DIR="${HOME}/.local/bin"
SCRIPT_DST="${BIN_DIR}/screenshot-to-clipboard.sh"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
STATE_DIR="${HOME}/.local/state"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Creating directories"
mkdir -p "$WATCH_DIR" "$BIN_DIR" "$STATE_DIR" "${HOME}/Library/LaunchAgents"

# Migrate an existing real ~/Desktop/Screenshots folder into ~/Screenshots, then
# replace it with a symlink. Skipped if it's already a symlink or doesn't exist.
if [ -d "$DESKTOP_LINK" ] && [ ! -L "$DESKTOP_LINK" ]; then
  echo "==> Migrating existing $DESKTOP_LINK -> $WATCH_DIR"
  mv "$DESKTOP_LINK"/.[!.]* "$WATCH_DIR"/ 2>/dev/null || true
  mv "$DESKTOP_LINK"/* "$WATCH_DIR"/ 2>/dev/null || true
  rm -f "$DESKTOP_LINK/.DS_Store"
  rmdir "$DESKTOP_LINK" 2>/dev/null || true
fi
if [ ! -e "$DESKTOP_LINK" ]; then
  ln -s "$WATCH_DIR" "$DESKTOP_LINK"
  echo "==> Symlinked $DESKTOP_LINK -> $WATCH_DIR"
fi

echo "==> Installing helper script -> $SCRIPT_DST"
cp "${SRC_DIR}/screenshot-to-clipboard.sh" "$SCRIPT_DST"
chmod +x "$SCRIPT_DST"

echo "==> Pointing macOS screenshots at $WATCH_DIR (and back to file mode)"
defaults write com.apple.screencapture target file
defaults write com.apple.screencapture location "$WATCH_DIR"
# Disable the floating thumbnail: it delays writing the file to disk (so the
# clipboard copy lags) and adds the ~5s preview. Off = instant save + instant copy.
defaults write com.apple.screencapture show-thumbnail -bool false
killall SystemUIServer 2>/dev/null || true

echo "==> Writing LaunchAgent -> $PLIST"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${SCRIPT_DST}</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>${WATCH_DIR}</string>
    </array>
    <!-- Allow rapid re-fire: default throttle is 10s, drop to 1s. -->
    <key>ThrottleInterval</key>
    <integer>1</integer>
    <key>StandardOutPath</key>
    <string>${STATE_DIR}/screenshot-clipboard.log</string>
    <key>StandardErrorPath</key>
    <string>${STATE_DIR}/screenshot-clipboard.log</string>
</dict>
</plist>
PLIST_EOF

echo "==> Loading agent"
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo
echo "Done. Screenshots save to $WATCH_DIR (shown on your Desktop as 'Screenshots')"
echo "and land on your clipboard automatically."
echo "Test it: press Cmd+Shift+4, grab a region, then Cmd+V somewhere."

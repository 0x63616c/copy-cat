#!/bin/bash
# copy-cat installer.
# macOS screenshots -> saved to ~/Desktop/Screenshots (historical record)
#                   -> AND copied to the clipboard automatically.
# Portable across machines: no third-party app, no extra permissions.

set -euo pipefail

LABEL="com.0x63616c.screenshot-clipboard"
WATCH_DIR="${HOME}/Desktop/Screenshots"
BIN_DIR="${HOME}/.local/bin"
SCRIPT_DST="${BIN_DIR}/screenshot-to-clipboard.sh"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
STATE_DIR="${HOME}/.local/state"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Creating directories"
mkdir -p "$WATCH_DIR" "$BIN_DIR" "$STATE_DIR" "${HOME}/Library/LaunchAgents"

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
echo "Done. Screenshots now save to $WATCH_DIR and land on your clipboard."
echo "Test it: press Cmd+Shift+4, grab a region, then Cmd+V somewhere."

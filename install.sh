#!/bin/bash
# copy-cat installer.
# macOS screenshots -> saved to a folder (historical record)
#                   -> AND copied to the clipboard automatically.
# Portable across machines: no third-party app, no extra permissions.
#
# It DETECTS where your screenshots are currently saved (defaults read
# com.apple.screencapture location) instead of guessing, then makes sure the
# watch folder is somewhere a launchd background agent can actually read.
#
# Why the folder can't be on the Desktop:
# The Desktop/Documents/Downloads are TCC-protected. A launchd background agent
# is denied read access to them ("Operation not permitted") without Full Disk
# Access, which isn't portable. So if your screenshots live in one of those, we
# move them to ~/Screenshots and leave a symlink behind for visibility.

set -euo pipefail

LABEL="com.0x63616c.screenshot-clipboard"
SAFE_DIR="${HOME}/Screenshots"
BIN_DIR="${HOME}/.local/bin"
SCRIPT_DST="${BIN_DIR}/screenshot-to-clipboard.sh"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
STATE_DIR="${HOME}/.local/state"
RAW_BASE="https://raw.githubusercontent.com/0x63616c/copy-cat/main"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo /nonexistent)"

mkdir -p "$BIN_DIR" "$STATE_DIR" "${HOME}/Library/LaunchAgents"

# --- Detect current screenshot save location ---------------------------------
CURRENT="$(defaults read com.apple.screencapture location 2>/dev/null || true)"
CURRENT="${CURRENT/#\~/$HOME}"; CURRENT="${CURRENT%/}"
[ -z "$CURRENT" ] && CURRENT="${HOME}/Desktop"   # macOS default when unset
echo "==> Detected screenshot location: $CURRENT"

is_protected() {  # TCC-gated folders a background agent can't read
  case "$1" in
    "$HOME/Desktop"|"$HOME/Desktop/"*) return 0 ;;
    "$HOME/Documents"|"$HOME/Documents/"*) return 0 ;;
    "$HOME/Downloads"|"$HOME/Downloads/"*) return 0 ;;
    *) return 1 ;;
  esac
}

# --- Decide the watch folder --------------------------------------------------
if ! is_protected "$CURRENT"; then
  WATCH_DIR="$CURRENT"
  echo "==> Location is readable by the agent. Watching it as-is (no move)."
  mkdir -p "$WATCH_DIR"
elif [ "$CURRENT" = "$HOME/Desktop" ]; then
  # Bare Desktop (the default). Don't touch existing Desktop files; just repoint
  # future screenshots to a readable folder.
  WATCH_DIR="$SAFE_DIR"
  echo "==> Screenshots dump onto the bare Desktop (TCC-protected)."
  echo "    Repointing future screenshots to $WATCH_DIR (existing Desktop files left alone)."
  mkdir -p "$WATCH_DIR"
else
  # A dedicated subfolder in a protected zone, e.g. ~/Desktop/Screenshots.
  # Migrate its contents to ~/Screenshots and symlink it back for visibility.
  WATCH_DIR="$SAFE_DIR"
  echo "==> Location is in a TCC-protected zone. Migrating -> $WATCH_DIR + symlink."
  mkdir -p "$WATCH_DIR"
  if [ -d "$CURRENT" ] && [ ! -L "$CURRENT" ]; then
    mv "$CURRENT"/.[!.]* "$WATCH_DIR"/ 2>/dev/null || true
    mv "$CURRENT"/* "$WATCH_DIR"/ 2>/dev/null || true
    rm -f "$CURRENT/.DS_Store"
    rmdir "$CURRENT" 2>/dev/null || true
  fi
  [ ! -e "$CURRENT" ] && ln -s "$WATCH_DIR" "$CURRENT" && echo "    Symlinked $CURRENT -> $WATCH_DIR"
fi

# --- Install helper script ----------------------------------------------------
echo "==> Installing helper script -> $SCRIPT_DST"
if [ -f "${SRC_DIR}/screenshot-to-clipboard.sh" ]; then
  cp "${SRC_DIR}/screenshot-to-clipboard.sh" "$SCRIPT_DST"   # local clone
else
  curl -fsSL "${RAW_BASE}/screenshot-to-clipboard.sh" -o "$SCRIPT_DST"   # piped via curl|bash
fi
chmod +x "$SCRIPT_DST"

# --- Configure macOS capture --------------------------------------------------
echo "==> Setting capture: file mode, location $WATCH_DIR, thumbnail off"
defaults write com.apple.screencapture target file
defaults write com.apple.screencapture location "$WATCH_DIR"
# The floating thumbnail delays writing the file to disk (lagging the clipboard
# copy) and adds the ~5s preview. Off = instant save + instant copy.
defaults write com.apple.screencapture show-thumbnail -bool false
killall SystemUIServer 2>/dev/null || true

# --- LaunchAgent --------------------------------------------------------------
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
echo "Done. Screenshots save to $WATCH_DIR and land on your clipboard automatically."
echo "Test it: press Cmd+Shift+4, grab a region, then Cmd+V somewhere."

#!/bin/bash
# Copies the newest screenshot in the watch folder to the clipboard.
# Triggered by a launchd LaunchAgent (WatchPaths) whenever the folder changes.
# Keeps the on-disk file (historical record) AND puts the image on the clipboard.

set -euo pipefail

WATCH_DIR="${HOME}/Desktop/Screenshots"
STATE_FILE="${HOME}/.local/state/screenshot-clipboard.last"
mkdir -p "$(dirname "$STATE_FILE")"

# Newest png/jpg by modification time (handles default macOS screenshot names).
newest="$(/bin/ls -t "$WATCH_DIR"/*.png "$WATCH_DIR"/*.jpg "$WATCH_DIR"/*.jpeg 2>/dev/null | head -n1 || true)"
[ -z "${newest:-}" ] && exit 0

# Skip if we already handled this exact file+mtime (folder also changes on delete).
sig="${newest}|$(/usr/bin/stat -f '%m' "$newest")"
[ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$sig" ] && exit 0

# Let the capture finish writing before reading it.
sleep 0.2

ext="${newest##*.}"
case "$ext" in
  png|PNG)  class="«class PNGf»" ;;
  jpg|JPG|jpeg|JPEG) class="«class JPEG»" ;;
  *) exit 0 ;;
esac

/usr/bin/osascript -e "set the clipboard to (read (POSIX file \"${newest}\") as ${class})"
echo "$sig" > "$STATE_FILE"

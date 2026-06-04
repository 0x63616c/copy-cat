#!/bin/bash
# Copies the newest screenshot in the watch folder to the clipboard.
# Triggered by a launchd LaunchAgent (WatchPaths) whenever the folder changes.
# Keeps the on-disk file (historical record) AND puts the image on the clipboard.

# Watch wherever macOS is actually told to save screenshots, so this never drifts
# from the real setting. Falls back to ~/Screenshots if unset.
WATCH_DIR="$(defaults read com.apple.screencapture location 2>/dev/null || echo "${HOME}/Screenshots")"
WATCH_DIR="${WATCH_DIR/#\~/$HOME}"; WATCH_DIR="${WATCH_DIR%/}"

STATE_FILE="${HOME}/.local/state/screenshot-clipboard.last"
LOG="${HOME}/.local/state/screenshot-clipboard.log"
mkdir -p "$(dirname "$STATE_FILE")"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

log "RUN: agent invoked (watching $WATCH_DIR)"

# Newest png/jpg by modification time (handles default macOS screenshot names).
newest="$(/bin/ls -t "$WATCH_DIR"/*.png "$WATCH_DIR"/*.jpg "$WATCH_DIR"/*.jpeg 2>/dev/null | head -n1 || true)"
if [ -z "${newest:-}" ]; then log "  no images found, exit"; exit 0; fi
log "  newest = $newest"

# Skip if we already handled this exact file+mtime (folder also changes on delete).
sig="${newest}|$(/usr/bin/stat -f '%m' "$newest")"
if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$sig" ]; then
  log "  unchanged since last copy, exit"
  exit 0
fi

# Let the capture finish writing before reading it.
sleep 0.2

ext="${newest##*.}"
case "$ext" in
  png|PNG)  class="«class PNGf»" ;;
  jpg|JPG|jpeg|JPEG) class="«class JPEG»" ;;
  *) log "  unsupported ext .$ext, exit"; exit 0 ;;
esac

err="$(/usr/bin/osascript -e "set the clipboard to (read (POSIX file \"${newest}\") as ${class})" 2>&1)"
rc=$?
if [ $rc -eq 0 ]; then
  echo "$sig" > "$STATE_FILE"
  log "  COPIED to clipboard ✓"
else
  log "  osascript FAILED rc=$rc: $err"
fi

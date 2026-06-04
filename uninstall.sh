#!/bin/bash
# Reverts copy-cat. Leaves your screenshots folder and its contents intact.

set -euo pipefail

LABEL="com.0x63616c.screenshot-clipboard"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"

echo "==> Unloading agent"
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true

echo "==> Removing files"
rm -f "$PLIST"
rm -f "${HOME}/.local/bin/screenshot-to-clipboard.sh"
rm -f "${HOME}/.local/state/screenshot-clipboard.last"
rm -f "${HOME}/.local/state/screenshot-clipboard.log"

echo "==> Re-enabling the screenshot thumbnail preview"
defaults write com.apple.screencapture show-thumbnail -bool true
killall SystemUIServer 2>/dev/null || true

echo "==> Restoring clipboard-only screenshots (optional default)"
echo "    Run this if you want clipboard-only again:"
echo "      defaults write com.apple.screencapture target clipboard && killall SystemUIServer"
echo
echo "Done. Your screenshots in ~/Screenshots (and the Desktop alias) were left untouched."

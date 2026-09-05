#!/bin/bash
# Sign nested Sparkle code from the inside out, then the host bundle.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/CopyCat.app"
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
SIGN_ARGS=(--force --sign "${SIGN_IDENTITY:--}")
if [[ -n "${SIGN_IDENTITY:-}" ]]; then SIGN_ARGS+=(--options runtime --timestamp); fi
for component in "$FRAMEWORK/Versions/B/XPCServices/Installer.xpc" "$FRAMEWORK/Versions/B/XPCServices/Downloader.xpc" "$FRAMEWORK/Versions/B/Autoupdate" "$FRAMEWORK/Versions/B/Updater.app" "$FRAMEWORK" "$APP"; do
  if [[ "$component" == *Downloader.xpc ]]; then
    codesign "${SIGN_ARGS[@]}" --preserve-metadata=entitlements "$component"
  else
    codesign "${SIGN_ARGS[@]}" "$component"
  fi
done
codesign --verify --deep --strict --verbose=2 "$APP"

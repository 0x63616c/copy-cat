#!/bin/bash
# One bundle path for development, local installs, and CI releases.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${ROOT}/CopyCat.app"
CONFIG="${CONFIG:-release}"
VERSION="$(sed -n 's/.*public static let version = "\([^"]*\)".*/\1/p' "$ROOT/Sources/CopyCatCore/Version.swift")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid source version' >&2; exit 1; }
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT" rev-list --count HEAD)}"
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo 'BUILD_NUMBER must be an integer' >&2; exit 1; }
ARGS=(-c "$CONFIG" --package-path "$ROOT")
if [[ "${UNIVERSAL:-0}" == 1 ]]; then ARGS+=(--arch arm64 --arch x86_64); fi
swift build "${ARGS[@]}"
BIN="$(swift build "${ARGS[@]}" --show-bin-path)/CopyCat"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp -f "$BIN" "$APP/Contents/MacOS/CopyCat"
cp -f "$ROOT/Resources/Info.plist.template" "$APP/Contents/Info.plist"
cp -f "$ROOT/Resources/AppIcon.icns" "$ROOT/Resources/menubar-cat.pdf" "$APP/Contents/Resources/"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CopyCatBuildNumber $BUILD_NUMBER" "$APP/Contents/Info.plist"
ditto "$ROOT/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
"$ROOT/scripts/sign.sh"
echo "Built CopyCat $VERSION ($BUILD_NUMBER): $APP"

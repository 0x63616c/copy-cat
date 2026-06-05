#!/bin/bash
# Build CopyCat in release and assemble a CopyCat.app bundle (menu bar agent).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${ROOT}/CopyCat.app"
EXE_NAME="CopyCat"

echo "==> Building release"
swift build -c release --package-path "$ROOT"
BIN="$(swift build -c release --package-path "$ROOT" --show-bin-path)/${EXE_NAME}"

echo "==> Assembling ${APP}"
rm -rf "$APP"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "$BIN" "${APP}/Contents/MacOS/${EXE_NAME}"
cp "${ROOT}/Resources/Info.plist.template" "${APP}/Contents/Info.plist"
cp "${ROOT}/Resources/AppIcon.icns" "${APP}/Contents/Resources/AppIcon.icns"
cp "${ROOT}/Resources/menubar-cat.pdf" "${APP}/Contents/Resources/menubar-cat.pdf"

echo "==> Built ${APP}"

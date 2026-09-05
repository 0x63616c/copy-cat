#!/bin/bash
# Package the built app and sign its update archive + feed for Sparkle.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/release-artifacts"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/CopyCat.app/Contents/Info.plist")"
RELEASE_TAG="${RELEASE_TAG:-v$VERSION}"
[[ "$RELEASE_TAG" == "v$VERSION" ]] || { echo 'Release tag does not match bundle version' >&2; exit 1; }
mkdir -p "$OUT"
rm -f "$OUT/CopyCat-macOS.zip" "$OUT/appcast.xml"
ditto -c -k --keepParent "$ROOT/CopyCat.app" "$OUT/CopyCat-macOS.zip"
ARGS=(--download-url-prefix "https://github.com/0x63616c/copy-cat/releases/download/$RELEASE_TAG/" --maximum-deltas 0 --maximum-versions 1 --link 'https://0x63616c.github.io/copy-cat/')
TOOL="$ROOT/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_PRIVATE_KEY" | "$TOOL" --ed-key-file - "${ARGS[@]}" "$OUT"
else
  "$TOOL" --account com.0x63616c.copy-cat.sparkle "${ARGS[@]}" "$OUT"
fi
python3 "$ROOT/scripts/check-appcast.py" "$OUT/appcast.xml" "$OUT/CopyCat-macOS.zip" "$VERSION"
(cd "$OUT" && shasum -a 256 CopyCat-macOS.zip > SHA256SUMS.txt)

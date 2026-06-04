#!/bin/bash
# Sign + notarize CopyCat.app for direct download (Developer ID).
# Requires:
#   - A "Developer ID Application: ..." cert in the login keychain.
#   - A stored notarytool keychain profile (see comment below).
# Env:
#   SIGN_IDENTITY  e.g. "Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE notarytool keychain profile name
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${ROOT}/CopyCat.app"
ZIP="${ROOT}/CopyCat.zip"

: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your stored notarytool profile}"

# One-time profile setup (run manually, not here):
#   xcrun notarytool store-credentials "$NOTARY_PROFILE" \
#     --apple-id you@example.com --team-id TEAMID --password APP_SPECIFIC_PW

echo "==> Codesigning"
codesign --force --options runtime --timestamp \
  --sign "$SIGN_IDENTITY" "$APP"

echo "==> Zipping for notarization"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting to notary service"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling"
xcrun stapler staple "$APP"

echo "==> Verifying"
spctl -a -vv -t install "$APP"
echo "==> Done: signed + notarized ${APP}"

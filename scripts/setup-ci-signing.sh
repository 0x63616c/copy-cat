#!/bin/bash
# Import release-only credentials into an ephemeral GitHub runner keychain.
set -euo pipefail
umask 077
: "${RUNNER_TEMP:?Run this helper on a disposable CI runner}"
: "${GITHUB_ENV:?Missing GitHub Actions environment file}"
: "${APPLE_CERTIFICATE_P12:?Missing encrypted Developer ID certificate}"
: "${APPLE_CERTIFICATE_PASSWORD:?Missing certificate passphrase}"
: "${APPLE_NOTARY_KEY:?Missing App Store Connect private key}"
: "${APPLE_NOTARY_KEY_ID:?Missing App Store Connect key ID}"
: "${APPLE_NOTARY_ISSUER_ID:?Missing App Store Connect issuer ID}"
: "${SIGN_IDENTITY:?Missing Developer ID signing identity}"

KEYCHAIN_PATH="$RUNNER_TEMP/copy-cat-signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -base64 32)"
printf '::add-mask::%s\n' "$KEYCHAIN_PASSWORD"
python3 - <<'PY'
import base64, os
from pathlib import Path
root = Path(os.environ['RUNNER_TEMP'])
for name, data in [('copy-cat-developer-id.p12', base64.b64decode(os.environ['APPLE_CERTIFICATE_P12'], validate=True)), ('copy-cat-notary.p8', os.environ['APPLE_NOTARY_KEY'].encode())]:
    path = root / name
    path.write_bytes(data)
    path.chmod(0o600)
PY
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$RUNNER_TEMP/copy-cat-developer-id.p12" -k "$KEYCHAIN_PATH" -P "$APPLE_CERTIFICATE_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
security list-keychains -d user -s "$KEYCHAIN_PATH"
xcrun notarytool store-credentials copy-cat-ci --key "$RUNNER_TEMP/copy-cat-notary.p8" --key-id "$APPLE_NOTARY_KEY_ID" --issuer "$APPLE_NOTARY_ISSUER_ID" --keychain "$KEYCHAIN_PATH"
rm -f "$RUNNER_TEMP/copy-cat-developer-id.p12" "$RUNNER_TEMP/copy-cat-notary.p8"
printf 'NOTARY_PROFILE=copy-cat-ci\nNOTARY_KEYCHAIN=%s\n' "$KEYCHAIN_PATH" >> "$GITHUB_ENV"

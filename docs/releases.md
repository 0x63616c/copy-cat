# Releasing CopyCat

## Cut a release

1. Update `CopyCatCore.version` in `Sources/CopyCatCore/Version.swift` using semantic versioning.
2. Update `CHANGELOG.md`, run `swift test` and `./scripts/bundle.sh`, and review the change.
3. Commit and push `main`.
4. Run `./scripts/release.sh 0.2.0` (substitute the new version).
5. Watch the **Release** workflow in GitHub Actions. Verify the downloaded ZIP’s checksum, app version, architectures, and launch behavior.

The helper requires a clean checkout on `main`, matching `origin/main`, and a version matching the source. It creates and pushes an annotated `vX.Y.Z` tag. CI validates the tag and main ancestry, runs the tests, builds both `arm64` and `x86_64`, verifies the app signature, and publishes `CopyCat-macOS.zip`, `SHA256SUMS.txt`, and signed `appcast.xml`. The stable latest-download URL always resolves to the newest GitHub release asset.

`CFBundleVersion` is the semantic source version, used for update comparison. `CopyCatBuildNumber` is stamped from `BUILD_NUMBER`: the workflow run number in CI, or the commit count locally. This avoids a local commit count blocking a newer CI release with a smaller run number. Do not manually change the template version; it is overwritten by the bundler. A bare debug executable shows the source version with “Development”.

## Signing status

The default CI pipeline creates an **ad-hoc-signed community build**. It does not claim Developer ID signing or notarization. Download, README, website, and release notes explain the first-launch requirement. The dedicated `SPARKLE_PRIVATE_KEY` GitHub Actions secret signs update archives and appcast metadata. That Ed25519 signature authenticates automatic updates; it is separate from Apple Developer ID signing/notarization. The release fails if this secret is missing.

For an Apple-notarized distribution, use an authorized Developer ID identity and stored notarytool profile on the signing Mac:

```sh
UNIVERSAL=1 ./scripts/bundle.sh
export SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export NOTARY_PROFILE='your-notary-profile'
./scripts/sign-notarize.sh
./scripts/appcast.sh
```

The signing helper applies the hardened runtime signature, submits for notarization, staples and validates the ticket, verifies Gatekeeper acceptance, and recreates `CopyCat.zip` **after** stapling. The appcast helper packages the final stapled bundle again and signs that exact archive and feed. Publish all three outputs from `release-artifacts/`; do not reuse the earlier archive or feed. Do not upload signing keys or credentials into the repository. If moving signing into CI later, use protected GitHub secrets and an ephemeral keychain; make a configured signing failure fail the release rather than silently downgrade.

## GitHub Pages

The static site is in `site/`. Enable **Settings → Pages → Source: GitHub Actions** once. The Pages workflow deploys validated assets on changes to `site/` or its workflow, and can be dispatched manually. It needs Pages write and OIDC permissions; releases use separate contents-write permission.

Preview locally with `python3 -m http.server 8765 --directory site`, then open `http://localhost:8765`. Check links/assets with `python3 scripts/check-site.py`. There is no JavaScript build toolchain or production dependency installation.

## Failure recovery

A failed workflow does not mean a release exists. Inspect the failed step and rerun the workflow only when the existing tag still identifies the intended, correct source. If the source needs changing, publish a new patch version; do not move a published release tag. Pages and Release are independent; verify both before announcing a launch.

## Automatic-update publishing

`./scripts/appcast.sh` packages the final signed app, generates and signs the feed with Sparkle 2.9.6, validates its version/URL/size and both Ed25519 signatures (including a tamper rejection check), and emits a checksum. CI reads the private key through standard input from `SPARKLE_PRIVATE_KEY`. For local signing it uses Keychain account `com.0x63616c.copy-cat.sparkle`; approve Keychain access for Sparkle’s signing tool if prompted.

The app reads `https://github.com/0x63616c/copy-cat/releases/latest/download/appcast.xml`. Each feed points to its immutable version-specific ZIP. The feed is a release asset, so website deployments cannot overwrite it. Every future tag publishes the update automatically; do not edit signed feeds or replace published archives without regenerating signatures.

Keep the private key backed up securely. To export it for a signing-machine transfer, use Sparkle’s `generate_keys --account com.0x63616c.copy-cat.sparkle -x <private-file>` and protect/remove the file after use. Never print it in logs, paste it into an issue, or change the bundled public key casually; installed apps rely on it.

Validate updates with an isolated older app bundle and a signed newer feed before changing the updater integration. For normal releases, verify the published appcast signature and that Check for Updates reaches the published feed. A first release cannot demonstrate an upgrade from an earlier public Sparkle-enabled version.

#!/bin/bash
# After committing a version bump: scripts/release.sh 0.2.0
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?Usage: scripts/release.sh 0.2.0}"
SOURCE_VERSION="$(sed -n 's/.*public static let version = "\([^"]*\)".*/\1/p' Sources/CopyCatCore/Version.swift)"
[[ "$VERSION" == "$SOURCE_VERSION" ]] || { echo "Version must match Version.swift ($SOURCE_VERSION)" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo 'Commit or stash changes first.' >&2; exit 1; }
[[ "$(git branch --show-current)" == main ]] || { echo 'Cut releases from main.' >&2; exit 1; }
git fetch origin main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || { echo 'Push main before releasing.' >&2; exit 1; }
git tag -a "v$VERSION" -m "CopyCat $VERSION"
git push origin "v$VERSION"
echo "Release started: https://github.com/0x63616c/copy-cat/actions"

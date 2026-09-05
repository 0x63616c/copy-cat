#!/bin/bash
# Install CopyCat's commit-message check beside any active Beads hooks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_PATH="$(git -C "$ROOT" config --get core.hooksPath || git -C "$ROOT" rev-parse --git-path hooks)"
[[ "$HOOKS_PATH" = /* ]] || HOOKS_PATH="$ROOT/$HOOKS_PATH"
TARGET="$HOOKS_PATH/commit-msg"

mkdir -p "$HOOKS_PATH"
if [[ -e "$TARGET" ]] && ! cmp -s "$ROOT/.githooks/commit-msg" "$TARGET"; then
  echo "Refusing to replace existing hook: $TARGET" >&2
  exit 1
fi
install -m 755 "$ROOT/.githooks/commit-msg" "$TARGET"
echo "Installed Conventional Commit check: $TARGET"

#!/bin/bash
# Dev loop: build CopyCat, refresh the CopyCat.app bundle, and relaunch the
# running menu bar instance. Debug build by default (fast); pass --release for
# the real release binary.
#
#   scripts/dev.sh            # debug build -> bundle -> relaunch (~1s)
#   scripts/dev.sh --release  # release build (what scripts/bundle.sh ships)
#   scripts/dev.sh --watch    # build once, then rebuild on every new commit
#
# --watch and --release compose (e.g. `--watch --release`). Watch mode polls
# `git rev-parse HEAD` and reruns the build whenever the commit changes; Ctrl-C
# to stop.
#
# The relaunch kills ONLY the instance running from this repo's CopyCat.app
# (matched by exact executable path), never a loose process pattern — this is a
# shared machine.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${ROOT}/CopyCat.app"
EXE_NAME="CopyCat"
EXE_PATH="${APP}/Contents/MacOS/${EXE_NAME}"

usage() {
  cat <<'EOF'
Usage: scripts/dev.sh [--release] [--watch]

  (no flags)   debug build -> bundle -> relaunch (~1s)
  --release    release build (what scripts/bundle.sh ships)
  --watch      build once, then rebuild on every new git commit (Ctrl-C to stop)
  --help, -h   show this help

Flags compose, e.g. `scripts/dev.sh --watch --release`.
EOF
}

CONFIG="debug"
WATCH=0
for arg in "$@"; do
  case "$arg" in
    --release) CONFIG="release" ;;
    --watch) WATCH=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; echo >&2; usage >&2; exit 2 ;;
  esac
done

build_and_relaunch() {
  echo "==> Building ${CONFIG}"
  swift build -c "$CONFIG" --package-path "$ROOT"
  local BIN
  BIN="$(swift build -c "$CONFIG" --package-path "$ROOT" --show-bin-path)/${EXE_NAME}"

  echo "==> Refreshing ${APP}"
  mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
  cp "$BIN" "$EXE_PATH"
  cp "${ROOT}/Resources/Info.plist.template" "${APP}/Contents/Info.plist"

  # Kill only the instance launched from this exact bundle path.
  local PID
  PID="$(pgrep -f "^${EXE_PATH}$" || true)"
  if [[ -n "$PID" ]]; then
    echo "==> Stopping running instance (pid ${PID})"
    kill "$PID" 2>/dev/null || true
    # Wait for it to exit so `open` relaunches a fresh process.
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      pgrep -f "^${EXE_PATH}$" >/dev/null 2>&1 || break
      sleep 0.2
    done
  fi

  echo "==> Relaunching"
  open "$APP"
  sleep 0.5
  local NEW_PID
  NEW_PID="$(pgrep -f "^${EXE_PATH}$" || true)"
  echo "==> Running pid ${NEW_PID:-<none>}"
}

build_and_relaunch

if [[ "$WATCH" -eq 1 ]]; then
  LAST="$(git -C "$ROOT" rev-parse HEAD)"
  echo "==> Watching for new commits (currently ${LAST:0:8}); Ctrl-C to stop"
  while true; do
    sleep 2
    HEAD="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || true)"
    if [[ -n "$HEAD" && "$HEAD" != "$LAST" ]]; then
      echo ""
      echo "==> New commit ${HEAD:0:8} (was ${LAST:0:8}); rebuilding"
      LAST="$HEAD"
      # Don't let one bad build kill the watcher.
      build_and_relaunch || echo "==> Build failed; staying up, will retry on next commit"
    fi
  done
fi

# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd prime` for full workflow context.

> **Architecture in one line:** Issues live in a local Dolt database
> (`.beads/dolt/`); cross-machine sync uses `bd dolt push/pull` (a
> git-compatible protocol), stored under `refs/dolt/data` on your git
> remote — separate from `refs/heads/*` where your code lives.
> `.beads/issues.jsonl` is a passive export, not the wire protocol.
>
> See [SYNC_CONCEPTS.md](https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md)
> for the one-screen overview and anti-patterns (don't treat JSONL as the
> source of truth; don't `bd import` during normal operation; don't
> reach for third-party Dolt hosting before trying the default).

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work atomically
bd close <id>         # Complete work
bd dolt push          # Push beads data to remote
```

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging on confirmation prompts.

Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i` (interactive) mode on some systems, causing the agent to hang indefinitely waiting for y/n input.

**Use these forms instead:**
```bash
# Force overwrite without prompting
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file

# For recursive operations
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

**Other commands that may prompt:**
- `scp` - use `-o BatchMode=yes` for non-interactive
- `ssh` - use `-o BatchMode=yes` to fail instead of prompting
- `apt-get` - use `-y` flag
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1` env var

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:970c3bf2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   bd dolt push
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->


## Project and scope

CopyCat is a native macOS 14+ menu bar screenshot utility by World Wide Webb. Favor small, direct Swift/AppKit/SwiftUI solutions. Do not add a service, framework, updater, or dependency unless the task needs it.

## Build and validation

```sh
swift test
./scripts/bundle.sh
./scripts/dev.sh                         # build/relaunch this checkout only
python3 scripts/check-site.py            # when site assets or links change
COPYCAT_SCREENSHOTS=1 COPYCAT_SCREEN_CAPTURE=1 swift test --filter RenderSnapshots
```

Use Swift 6+. Normal tests must not mutate real login items, preferences, clipboard, or screenshot folders. Product rendering is opt-in and uses synthetic fixtures. Inspect generated images before committing. Never use personal screenshots as public assets.

## Architecture and conventions

- `CopyCatCore` holds data and pure logic; `CopyCatKit` holds platform adapters, `AppController`, and SwiftUI views; `CopyCat` boots the app.
- `PopoverMetrics` is the shared source for view/popover sizing. Keep controls keyboard-accessible and labeled for VoiceOver.
- macOS owns Open at Login through `SMAppService.mainApp`; do not save a second Boolean in app settings.
- `Sources/CopyCatCore/Version.swift` is the release version source. Bundle version fields are stamped by `scripts/bundle.sh`; runtime UI reads the running app bundle.
- Log user-facing actions through `AppLog`, but never add image content, credentials, or unnecessarily sensitive detail. Logs already contain local paths/filenames; redact before sharing.
- `UpdateManager` uses Sparkle for automatic updates. Never replace signature validation with custom download/install code. Tests and bare executables must not start the updater. Keep release feeds/archives signed, and keep all private signing material out of Git/logs.
- `site/` is plain static HTML/CSS, published by GitHub Pages. Use relative assets for the repository base path, accessible text, and accurate product claims.
- `CLAUDE.md` points here. Keep substantive guidance in this file.

## Release and handoff

## Commits and automated releases

Use Conventional Commits for every non-merge commit: `feat:` for a user-visible feature, `fix:` or `perf:` for a user-visible correction, and `docs:`, `test:`, `ci:`, `build:`, `chore:`, `refactor:`, or `style:` when no product release is needed. Add `!` or a `BREAKING CHANGE:` footer only for an intentional major release.

CI enforces this policy. Run `./scripts/install-git-hooks.sh` once for the same local feedback; it installs only a `commit-msg` hook beside active Beads hooks. A release also requires a change under `Sources/`, `Resources/`, or `Package.swift`, so documentation, website, and CI-only changes do not publish an app update. The release workflow automatically bumps `Version.swift`, updates `CHANGELOG.md`, tags, signs, notarizes, and publishes qualifying changes merged to `main`; do not manually bump the version, edit an Unreleased entry, or run `scripts/release.sh` for ordinary releases.

Follow the conservative Beads profile unless the user explicitly authorizes commit/push/release. When authorized, validate the exact changes, get an independent agent review if requested, commit only the intended files, push, and verify CI and release/Pages outcomes. Do not treat a local build as a successful deployment.

Release with `scripts/release.sh X.Y.Z` after updating the version/changelog and pushing main. Do not move published tags. Releases from 0.3.1 must pass Developer ID signing, Apple notarization, stapling, and Gatekeeper verification before Sparkle signing and publication. Never silently downgrade signing. Never upload signing credentials to source control. See `docs/releases.md`.

Beads failures: preserve existing `.beads` data and report exact errors; do not force-discard remote history to unblock ordinary coding. Use Beads for work tracking; do not introduce markdown task lists. Recovery and any temporary tracking location must be disclosed in the handoff.

# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:6cd5cc61 -->
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
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->


## Build & Test

_Add your build and test commands here_

```bash
# Example:
# npm install
# npm test
```

## Architecture Overview

_Add a brief overview of your project architecture_

## Conventions & Patterns

### Logging / debugging

- **Runtime activity log:** `~/Library/Application Support/copy-cat/copy-cat.log` (next to `config.json`). Append-only, auto-trimmed to ~512 KB once it passes ~1 MB.
- Written through `AppLog.shared` (`Sources/CopyCatCore/AppLog.swift`); thread-safe, serialized on a background queue. Use `.info` / `.warn` / `.error`.
- Goal is **full-detail tracing of everything the app does.** Logged: app start + resolved watch folder, bookmark resolution, folder updates (count + delta), new screenshots (copied / queued / skipped), manual copy, settings open/close + gear/back clicks, copy-toggle + watch-folder changes, Choose… click + picker cancel, popover open/close, tile hover enter/leave, access OK/DENIED transitions, reveal/copy-path, Spotlight query start/re-point.
- In-app access: **Settings → Diagnostics → "Open Logs"** opens the file in Console. Tail it live with `tail -f "$HOME/Library/Application Support/copy-cat/copy-cat.log"`.
- When adding a new user-facing action, add an `AppLog.shared.info(...)` line for it.

### Commit & deploy

- **Commit SUPER often.** Small, frequent commits to `main`.
- **If the working tree is dirty, just commit and push it** — don't sit on dirty state, don't ask first. Commits to `main` are how changes get deployed here.
- Build before committing code (`swift build`); otherwise commit freely.

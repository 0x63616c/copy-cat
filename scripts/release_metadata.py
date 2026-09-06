#!/usr/bin/env python3
"""Validate Conventional Commits and prepare CopyCat's next release."""

from __future__ import annotations

import argparse
import datetime as dt
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
VERSION_FILE = ROOT / "Sources/CopyCatCore/Version.swift"
CHANGELOG = ROOT / "CHANGELOG.md"
CONVENTIONAL = re.compile(r"^(?P<type>[a-z]+)(?:\([^)]+\))?(?P<breaking>!)?: (?P<description>.+)$")
ALLOWED_TYPES = {"build", "chore", "ci", "docs", "feat", "fix", "perf", "refactor", "revert", "style", "test"}
RELEASE_TYPES = {"feat": 1, "fix": 0, "perf": 0, "revert": 0}
VERSION = re.compile(r'public static let version = "([0-9]+)\.([0-9]+)\.([0-9]+)"')


@dataclass(frozen=True)
class Commit:
    sha: str
    subject: str
    body: str
    type: str
    breaking: bool
    paths: tuple[str, ...]


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True)


def commits(revision_range: str) -> list[Commit]:
    raw = git("log", "--no-merges", "--format=%H%x1e%s%x1e%B%x1f", revision_range)
    result: list[Commit] = []
    for record in raw.split("\x1f"):
        if not record.strip():
            continue
        sha, subject, body = record.split("\x1e", 2)
        match = CONVENTIONAL.match(subject)
        if not match or match["type"] not in ALLOWED_TYPES:
            raise ValueError(f"{sha[:8]}: use a Conventional Commit, got: {subject}")
        result.append(Commit(
            sha=sha,
            subject=subject,
            body=body,
            type=match["type"],
            breaking=bool(match["breaking"]) or "BREAKING CHANGE:" in body,
            paths=tuple(git("diff-tree", "--no-commit-id", "--name-only", "-r", sha).splitlines()),
        ))
    return result


def validate_message(message: str) -> None:
    subject = message.splitlines()[0] if message.splitlines() else ""
    match = CONVENTIONAL.match(subject)
    if not match or match["type"] not in ALLOWED_TYPES:
        raise ValueError(f"use a Conventional Commit, got: {subject}")


def source_version() -> tuple[int, int, int]:
    match = VERSION.search(VERSION_FILE.read_text())
    if not match:
        raise ValueError(f"Could not read source version from {VERSION_FILE}")
    return tuple(map(int, match.groups()))


def latest_tag() -> tuple[str, tuple[int, int, int]]:
    tag = git("describe", "--tags", "--abbrev=0").strip()
    match = re.fullmatch(r"v([0-9]+)\.([0-9]+)\.([0-9]+)", tag)
    if not match:
        raise ValueError(f"Latest tag is not vX.Y.Z: {tag}")
    return tag, tuple(map(int, match.groups()))


def is_product_change(entry: Commit) -> bool:
    return any(path == "Package.swift" or path.startswith(("Sources/", "Resources/")) for path in entry.paths)


def is_releasable(entry: Commit) -> bool:
    return is_product_change(entry) and (entry.type in RELEASE_TYPES or entry.breaking)


def next_version(current: tuple[int, int, int], entries: list[Commit]) -> tuple[int, int, int] | None:
    releasing = [entry for entry in entries if is_releasable(entry)]
    if not releasing:
        return None
    if any(entry.breaking for entry in releasing):
        return current[0] + 1, 0, 0
    if any(RELEASE_TYPES.get(entry.type) == 1 for entry in releasing):
        return current[0], current[1] + 1, 0
    return current[0], current[1], current[2] + 1


def render_changelog(version: str, entries: list[Commit], today: str) -> str:
    text = CHANGELOG.read_text()
    match = re.search(r"^## Unreleased\n(?P<body>.*?)(?=^## |\Z)", text, re.MULTILINE | re.DOTALL)
    if not match:
        raise ValueError("CHANGELOG.md must begin with an Unreleased section")
    notes = match["body"].strip()
    if not notes:
        notes = "\n".join(
            f"- {entry.subject.split(': ', 1)[1]}"
            for entry in entries
            if is_releasable(entry)
        )
    release = f"## Unreleased\n\n## {version} — {today}\n\n{notes}\n\n"
    return text[:match.start()] + release + text[match.end():]


def render_release_notes(changelog: str, version: str) -> str:
    match = re.search(rf"^## {re.escape(version)} — .*?\n(?P<body>.*?)(?=^## |\Z)", changelog, re.MULTILINE | re.DOTALL)
    if not match:
        raise ValueError(f"CHANGELOG.md has no entry for {version}")
    notes = match["body"].strip()
    tag = f"v{version}"
    return "\n".join((
        f"# What's new in CopyCat {version}",
        "",
        notes,
        "",
        f"[View this release on GitHub](https://github.com/0x63616c/copy-cat/releases/tag/{tag})",
        f"[View the full changelog](https://github.com/0x63616c/copy-cat/blob/{tag}/CHANGELOG.md)",
        "",
    ))


def plan() -> tuple[str, tuple[int, int, int] | None, list[Commit]]:
    tag, tagged_version = latest_tag()
    current = source_version()
    if current != tagged_version:
        raise ValueError(f"Source version {'.'.join(map(str, current))} does not match {tag}")
    entries = commits(f"{tag}..HEAD")
    return tag, next_version(current, entries), entries


def main() -> int:
    parser = argparse.ArgumentParser()
    subcommands = parser.add_subparsers(dest="command", required=True)
    check = subcommands.add_parser("check")
    check.add_argument("revision_range")
    check_message = subcommands.add_parser("check-message")
    check_message.add_argument("message_file", type=Path)
    plan_command = subcommands.add_parser("plan")
    plan_command.add_argument("--github-output", type=Path)
    prepare = subcommands.add_parser("prepare")
    prepare.add_argument("version")
    notes = subcommands.add_parser("notes")
    notes.add_argument("version")
    notes.add_argument("output", type=Path)
    args = parser.parse_args()

    try:
        if args.command == "check":
            checked = commits(args.revision_range)
            print(f"Conventional Commits OK: {len(checked)} commit(s)")
            return 0
        if args.command == "check-message":
            validate_message(args.message_file.read_text())
            print("Conventional Commit OK")
            return 0
        if args.command == "notes":
            args.output.write_text(render_release_notes(CHANGELOG.read_text(), args.version))
            print(f"Wrote release notes: {args.output}")
            return 0
        if args.command == "plan":
            tag, version, _ = plan()
            release = version is not None
            print(f"Release {'v' + '.'.join(map(str, version)) if release else 'not needed'} from {tag}")
            if args.github_output:
                args.github_output.write_text(f"release={'true' if release else 'false'}\nversion={'.'.join(map(str, version)) if version else ''}\n")
            return 0
        _, version, entries = plan()
        if version is None or args.version != ".".join(map(str, version)):
            raise ValueError("Requested version does not match the release plan")
        VERSION_FILE.write_text(VERSION.sub(f'public static let version = "{args.version}"', VERSION_FILE.read_text()))
        CHANGELOG.write_text(render_changelog(args.version, entries, dt.date.today().isoformat()))
        print(f"Prepared v{args.version}")
        return 0
    except (subprocess.CalledProcessError, ValueError) as error:
        print(f"release metadata: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

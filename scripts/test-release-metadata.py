#!/usr/bin/env python3
"""Small executable checks for release_metadata's SemVer decisions."""

import importlib.util
import sys
from pathlib import Path


SCRIPT = Path(__file__).with_name("release_metadata.py")
spec = importlib.util.spec_from_file_location("release_metadata", SCRIPT)
release_metadata = importlib.util.module_from_spec(spec)
assert spec.loader
sys.modules[spec.name] = release_metadata
spec.loader.exec_module(release_metadata)


def commit(subject: str, body: str = "", paths = ("Sources/CopyCatKit/Foo.swift",)):
    match = release_metadata.CONVENTIONAL.match(subject)
    assert match
    return release_metadata.Commit("deadbeef", subject, body, match["type"], bool(match["breaking"]) or "BREAKING CHANGE:" in body, paths)


assert release_metadata.next_version((0, 3, 2), [commit("docs: clarify install")]) is None
assert release_metadata.next_version((0, 3, 2), [commit("feat: rewrite README", paths=("README.md",))]) is None
assert release_metadata.next_version((0, 3, 2), [commit("fix: retain thumbnail preference")]) == (0, 3, 3)
assert release_metadata.next_version((0, 3, 2), [commit("feat: add screenshot grouping")]) == (0, 4, 0)
assert release_metadata.next_version((0, 3, 2), [commit("feat!: replace screenshot format")]) == (1, 0, 0)
release_metadata.validate_message("fix: repair update check\n")
notes = release_metadata.render_release_notes("# Changelog\n\n## 0.4.0 — 2026-09-05\n\n- Add updater notes.\n", "0.4.0")
assert "Add updater notes." in notes and "/releases/tag/v0.4.0" in notes and "/blob/v0.4.0/CHANGELOG.md" in notes
print("release metadata checks passed")

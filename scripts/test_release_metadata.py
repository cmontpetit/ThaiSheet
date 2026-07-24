#!/usr/bin/env python3
"""Tests for release metadata synchronization."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("sync_release_metadata.py")
SPEC = importlib.util.spec_from_file_location("sync_release_metadata", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
release_metadata = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = release_metadata
SPEC.loader.exec_module(release_metadata)


class ReleaseMetadataTests(unittest.TestCase):
    def test_checked_in_files_are_synchronized(self) -> None:
        release = release_metadata.load_release()
        for path, expected in release_metadata.expected_files(release).items():
            self.assertEqual(
                path.read_text(encoding="utf-8"),
                expected,
                f"{path.relative_to(release_metadata.ROOT)} is stale",
            )

    def test_tag_contains_public_version_and_build(self) -> None:
        release = release_metadata.Release(
            version="1.2.3",
            build=42,
            date="2026-07-23",
            notes=("A useful change.",),
        )
        self.assertEqual(release.tag, "v1.2.3-build42")

    def test_github_notes_reuse_curated_notes(self) -> None:
        release = release_metadata.Release(
            version="1.2.3",
            build=42,
            date="2026-07-23",
            notes=("First change.", "Second change."),
        )
        self.assertEqual(
            release_metadata.github_notes(release),
            (
                "- First change.\n"
                "- Second change.\n\n"
                "App Store version 1.2.3, build 42.\n"
            ),
        )


if __name__ == "__main__":
    unittest.main()

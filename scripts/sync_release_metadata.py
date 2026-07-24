#!/usr/bin/env python3
"""Synchronize release metadata from release/current.json."""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = ROOT / "release" / "current.json"


@dataclass(frozen=True)
class Release:
    version: str
    build: int
    date: str
    notes: tuple[str, ...]

    @property
    def tag(self) -> str:
        return f"v{self.version}-build{self.build}"


def load_release() -> Release:
    data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    version = data.get("version")
    build = data.get("build")
    date = data.get("date")
    notes = data.get("notes")

    if not isinstance(version, str) or not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("version must use semantic version form, for example 1.1.1")
    if not isinstance(build, int) or isinstance(build, bool) or build < 1:
        raise ValueError("build must be a positive integer")
    if not isinstance(date, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
        raise ValueError("date must use YYYY-MM-DD form")
    if (
        not isinstance(notes, list)
        or not notes
        or not all(isinstance(note, str) and note.strip() for note in notes)
    ):
        raise ValueError("notes must be a non-empty list of non-empty strings")

    return Release(version, build, date, tuple(note.strip() for note in notes))


def replace_checked(
    text: str,
    pattern: str,
    replacement: str,
    *,
    expected_count: int = 1,
    flags: int = 0,
) -> str:
    updated, count = re.subn(pattern, replacement, text, flags=flags)
    if count != expected_count:
        raise ValueError(
            f"expected {expected_count} match(es) for {pattern!r}, found {count}"
        )
    return updated


def update_project(text: str, release: Release) -> str:
    version_count = len(re.findall(r"MARKETING_VERSION = [^;]+;", text))
    build_count = len(re.findall(r"CURRENT_PROJECT_VERSION = [^;]+;", text))
    if version_count < 2 or build_count < 2:
        raise ValueError("could not find all Xcode target version settings")
    text = re.sub(
        r"MARKETING_VERSION = [^;]+;",
        f"MARKETING_VERSION = {release.version};",
        text,
    )
    return re.sub(
        r"CURRENT_PROJECT_VERSION = [^;]+;",
        f"CURRENT_PROJECT_VERSION = {release.build};",
        text,
    )


def update_app_store_metadata(text: str, release: Release) -> str:
    text = replace_checked(
        text,
        r"^- Version: `[^`]+`$",
        f"- Version: `{release.version}`",
        flags=re.MULTILINE,
    )
    text = replace_checked(
        text,
        r"^- Build: `[^`]+`$",
        f"- Build: `{release.build}`",
        flags=re.MULTILINE,
    )
    notes = "\n".join(f"- {note}" for note in release.notes)
    text = replace_checked(
        text,
        r"(?<=## What's New\n\n).*?(?=\n\n## )",
        notes,
        flags=re.DOTALL,
    )
    text = replace_checked(
        text,
        r"final signed \d+(?:\.\d+)+ \(\d+\) archive",
        f"final signed {release.version} ({release.build}) archive",
    )
    text = replace_checked(
        text,
        r"Upload and select build \d+ for version \d+(?:\.\d+)+",
        f"Upload and select build {release.build} for version {release.version}",
    )
    text = replace_checked(
        text,
        r"internal TestFlight group, add build \d+",
        f"internal TestFlight group, add build {release.build}",
    )
    return replace_checked(
        text,
        r"Create the \d+(?:\.\d+)+ App Store version",
        f"Create the {release.version} App Store version",
    )


def update_readme(text: str, release: Release) -> str:
    return replace_checked(
        text,
        r"\*\*Latest release: [^*]+\.\*\*",
        f"**Latest release: {release.version}.**",
    )


def update_changelog(text: str, release: Release) -> str:
    section = (
        f"## {release.version} - {release.date}\n\n"
        + "\n".join(f"- {note}" for note in release.notes)
    )
    existing = rf"^## {re.escape(release.version)} - .*?(?=^## |\Z)"
    if re.search(existing, text, flags=re.MULTILINE | re.DOTALL):
        return re.sub(
            existing,
            section + "\n\n",
            text,
            count=1,
            flags=re.MULTILINE | re.DOTALL,
        ).rstrip() + "\n"

    marker = "All notable changes to ThaiSheet will be documented in this file.\n"
    if marker not in text:
        raise ValueError("could not find changelog introduction")
    return text.replace(marker, f"{marker}\n{section}\n", 1)


def update_website(text: str, release: Release) -> str:
    text = replace_checked(
        text,
        r'(<meta name="description" content="ThaiSheet )[^ ]+( is )',
        rf"\g<1>{release.version}\g<2>",
    )
    text = replace_checked(
        text,
        r'<p class="release-badge">Version [^<]+</p>',
        f'<p class="release-badge">Version {release.version}</p>',
    )
    text = replace_checked(
        text,
        r'(<h2 id="release-notes-title">What&rsquo;s new in )[^<]+(</h2>)',
        rf"\g<1>{release.version}\g<2>",
    )
    note_items = "\n".join(
        f"        <li>{html.escape(note)}</li>" for note in release.notes
    )
    return replace_checked(
        text,
        (
            r'(<section class="release-notes" aria-labelledby="release-notes-title">\n'
            r'      <h2 id="release-notes-title">.*?</h2>\n'
            r"      <ul>\n).*?(\n      </ul>)"
        ),
        rf"\g<1>{note_items}\g<2>",
        flags=re.DOTALL,
    )


def expected_files(release: Release) -> dict[Path, str]:
    transforms = {
        ROOT / "ThaiSheet.xcodeproj" / "project.pbxproj": update_project,
        ROOT / "APP_STORE_METADATA.md": update_app_store_metadata,
        ROOT / "README.md": update_readme,
        ROOT / "CHANGELOG.md": update_changelog,
        ROOT / "docs" / "index.html": update_website,
    }
    return {
        path: transform(path.read_text(encoding="utf-8"), release)
        for path, transform in transforms.items()
    }


def github_notes(release: Release) -> str:
    bullets = "\n".join(f"- {note}" for note in release.notes)
    return (
        f"{bullets}\n\n"
        f"App Store version {release.version}, build {release.build}.\n"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--check",
        action="store_true",
        help="verify generated files without changing them",
    )
    mode.add_argument(
        "--github-notes",
        action="store_true",
        help="print Markdown release notes for GitHub",
    )
    args = parser.parse_args()

    try:
        release = load_release()
        if args.github_notes:
            print(github_notes(release), end="")
            return 0

        expected = expected_files(release)
        stale = [
            path.relative_to(ROOT)
            for path, content in expected.items()
            if path.read_text(encoding="utf-8") != content
        ]
        if args.check:
            if stale:
                print(
                    "Release metadata is stale: "
                    + ", ".join(str(path) for path in stale),
                    file=sys.stderr,
                )
                return 1
            print(
                f"Release metadata is synchronized for {release.version} "
                f"({release.build})."
            )
            return 0

        for path, content in expected.items():
            path.write_text(content, encoding="utf-8")
        print(
            f"Synchronized {len(expected)} files for {release.version} "
            f"({release.build})."
        )
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

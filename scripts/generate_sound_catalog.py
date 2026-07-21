#!/usr/bin/env python3
"""Generate the public sound catalog data and verify bundled sound assets."""

import argparse
import hashlib
import json
from pathlib import Path

from sound_inventory import (
    BUNDLED_VOICE_KEYS,
    CATALOG_TYPE_LABELS,
    bundled_voice_filename,
    expected_bundled_filenames,
    load_sound_inventory,
)


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
CHEATSHEET_DIR = PROJECT_ROOT / "ThaiSheet" / "Resources" / "cheatsheet"
SOUNDS_DIR = PROJECT_ROOT / "ThaiSheet" / "Resources" / "sounds"
METADATA_PATH = SCRIPT_DIR / "recorded_audio_metadata.json"
OUTPUT_PATH = PROJECT_ROOT / "docs" / "sounds-data.js"


def build_catalog(audio_dir: Path, metadata_path: Path) -> dict:
    items = load_sound_inventory(CHEATSHEET_DIR)
    expected_files = expected_bundled_filenames(items)
    existing_files = {path.name for path in audio_dir.glob("*.mp3")}
    missing = sorted(expected_files - existing_files)
    stale = sorted(existing_files - expected_files)
    if missing or stale:
        lines = ["Bundled sound inventory does not match the MP3 directory."]
        if missing:
            lines.append(f"Missing: {', '.join(missing)}")
        if stale:
            lines.append(f"Stale: {', '.join(stale)}")
        raise SystemExit("\n".join(lines))

    with metadata_path.open(encoding="utf-8") as metadata_file:
        metadata = json.load(metadata_file)
    required_metadata = {"provider", "voice", "processing", "status", "voices"}
    if not required_metadata.issubset(metadata):
        missing_metadata = ", ".join(sorted(required_metadata - set(metadata)))
        raise SystemExit(f"Recorded audio metadata is missing: {missing_metadata}")

    voices = metadata["voices"]
    required_voice_metadata = {"key", "label", "provider", "voice", "processing", "default"}
    for voice in voices:
        if not required_voice_metadata.issubset(voice):
            missing_voice_metadata = ", ".join(sorted(required_voice_metadata - set(voice)))
            raise SystemExit(f"Recorded voice metadata is missing: {missing_voice_metadata}")
    voice_keys = tuple(voice["key"] for voice in voices)
    if set(voice_keys) != set(BUNDLED_VOICE_KEYS) or len(voice_keys) != len(BUNDLED_VOICE_KEYS):
        raise SystemExit(
            "Recorded voice metadata must contain each bundled voice exactly once: "
            + ", ".join(BUNDLED_VOICE_KEYS)
        )
    default_voices = [voice["key"] for voice in voices if voice["default"]]
    if len(default_voices) != 1:
        raise SystemExit("Recorded voice metadata must identify exactly one default voice")

    catalog_items = []
    for item in items:
        item_data = item.catalog_dict()
        recordings = {}
        for voice_key in voice_keys:
            filename = bundled_voice_filename(item.filename, voice_key)
            filepath = audio_dir / filename
            digest = hashlib.sha256(filepath.read_bytes()).hexdigest()
            recordings[voice_key] = {
                "filename": filename,
                "bytes": filepath.stat().st_size,
                "sha256": digest,
                "revision": digest[:12],
            }
        item_data["recordings"] = recordings
        catalog_items.append(item_data)

    counts = {
        catalog_type: sum(
            (item.catalog_type or item.sound_type) == catalog_type
            for item in items
        )
        for catalog_type in CATALOG_TYPE_LABELS
    }
    return {
        "schemaVersion": 2,
        "repository": "cmontpetit/ThaiSheet",
        "branch": "main",
        "defaultVoice": default_voices[0],
        "voices": voices,
        "fileCount": len(catalog_items) * len(voices),
        "counts": counts,
        "typeLabels": CATALOG_TYPE_LABELS,
        "items": catalog_items,
    }


def rendered_catalog(catalog: dict) -> str:
    json_text = json.dumps(catalog, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    return f"window.THAISHEET_SOUND_CATALOG = {json_text};\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate or check the website sound catalog")
    parser.add_argument("--check", action="store_true", help="Fail if committed catalog data is stale")
    parser.add_argument("--audio-dir", default=str(SOUNDS_DIR))
    parser.add_argument("--metadata", default=str(METADATA_PATH))
    parser.add_argument("--output", default=str(OUTPUT_PATH))
    args = parser.parse_args()

    audio_dir = Path(args.audio_dir).expanduser().resolve()
    metadata_path = Path(args.metadata).expanduser().resolve()
    output_path = Path(args.output).expanduser().resolve()
    catalog = build_catalog(audio_dir, metadata_path)
    rendered = rendered_catalog(catalog)

    if args.check:
        if not output_path.exists() or output_path.read_text(encoding="utf-8") != rendered:
            print("Website sound catalog is stale.")
            print("Run: python3 scripts/generate_sound_catalog.py")
            return 1
        print(
            "Website sound catalog is current "
            f"({len(catalog['items'])} entries / {catalog['fileCount']} MP3 files)."
        )
        return 0

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered, encoding="utf-8")
    print(f"Wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

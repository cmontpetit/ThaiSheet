#!/usr/bin/env python3
"""Generate a full bundled sound set with ElevenLabs (eleven_v3, the only Thai-capable
model), using the canonical inventory so filenames/synthesis text match generate_sounds.py.

Every clip is normalized to -18 LUFS / -1.5 dBTP (matching the bundled Google set), so
the recorded voices are level-matched. Reads ELEVENLABS_API_KEY from the environment.

    python3 scripts/generate_elevenlabs_sounds.py \
        --voice-id XrExE9yKIg1WjnnlVkGX \
        --output-dir scratchpad/matilda-candidate

Candidate directories use voice-neutral inventory names. Passing the production
`ThaiSheet/Resources/sounds` directory writes the explicit `_matilda` suffix.

Empty responses (ElevenLabs returns 0 bytes for glyphs it cannot voice, e.g. an isolated
ฦๅ) are retried, then reported and skipped rather than crashing.
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR))

from sound_inventory import bundled_voice_filename, load_sound_inventory  # noqa: E402
from generate_sounds import inspect_audio  # noqa: E402

DEFAULT_MODEL = "eleven_v3"
LUFS = -18.0
MIN_DURATION = 0.35
MIN_PEAK_DB = -24.0


def synthesize(voice_id: str, model: str, text: str, api_key: str, retries: int) -> bytes:
    payload = json.dumps({"text": text, "model_id": model}).encode()
    req = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format=mp3_44100_128",
        data=payload,
        headers={"xi-api-key": api_key, "Content-Type": "application/json", "Accept": "audio/mpeg"},
        method="POST",
    )
    for attempt in range(retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            retryable = e.code == 429 or 500 <= e.code < 600
            if retryable and attempt < retries:
                delay = min(2 ** attempt, 30)
                print(f"    HTTP {e.code}; retrying in {delay}s...")
                time.sleep(delay)
                continue
            raise SystemExit(f"ElevenLabs HTTP {e.code}: {e.read().decode()[:200]}") from e
        except urllib.error.URLError as e:
            if attempt < retries:
                time.sleep(min(2 ** attempt, 30))
                continue
            raise SystemExit(f"ElevenLabs request failed: {e.reason}") from e
    raise SystemExit("unreachable")


def normalize(src: Path, dst: Path) -> None:
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(src),
         "-filter:a", f"loudnorm=I={LUFS:g}:LRA=7:TP=-1.5",
         "-ar", "24000", "-b:a", "64k", str(dst)],
        check=True,
    )


def main() -> int:
    p = argparse.ArgumentParser(description="Generate a bundled sound set via ElevenLabs")
    p.add_argument("--voice-id", required=True)
    p.add_argument("--model", default=DEFAULT_MODEL)
    p.add_argument("--output-dir", required=True)
    p.add_argument("--force", action="store_true")
    p.add_argument("--only-type", help="Restrict to one sound_type (e.g. 'consonant')")
    p.add_argument("--keep-consonant-spaces", action="store_true",
                   help="Keep the space in consonant names. Default strips it: eleven_v3 "
                        "renders the space between the letter-sound and example word as an "
                        "unnaturally long pause (e.g. 'คอ ควาย'), so we synthesize 'คอควาย'.")
    p.add_argument("--quality-retries", type=int, default=3)
    p.add_argument("--retries", type=int, default=3)
    args = p.parse_args()

    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        raise SystemExit("Set ELEVENLABS_API_KEY in the environment.")

    out = Path(args.output_dir)
    if not out.is_absolute():
        out = PROJECT_ROOT / out
    out.mkdir(parents=True, exist_ok=True)
    production_sounds_dir = (PROJECT_ROOT / "ThaiSheet" / "Resources" / "sounds").resolve()
    writes_bundled_set = out.resolve() == production_sounds_dir

    inv = load_sound_inventory(PROJECT_ROOT / "ThaiSheet" / "Resources" / "cheatsheet")
    print(f"Voice {args.voice_id} · model {args.model} · {len(inv)} clips -> {out}")

    cache: dict[str, bytes] = {}
    written = skipped = failed = 0
    empties: list[str] = []

    for it in inv:
        if args.only_type and it.sound_type != args.only_type:
            continue
        filename = bundled_voice_filename(it.filename, "matilda") if writes_bundled_set else it.filename
        dst = out / filename
        if dst.exists() and not args.force:
            skipped += 1
            continue
        text = it.synthesis_text
        if it.sound_type == "consonant" and not args.keep_consonant_spaces:
            text = text.replace(" ", "")
        if text in cache:
            dst.write_bytes(cache[text])
            written += 1
            continue

        ok = False
        for q in range(args.quality_retries + 1):
            audio = synthesize(args.voice_id, args.model, text, api_key, args.retries)
            if len(audio) < 200:
                print(f"  ⚠️  empty audio for {it.filename} ({text!r}) attempt {q + 1}")
                continue
            with tempfile.TemporaryDirectory() as td:
                raw = Path(td) / "raw.mp3"
                raw.write_bytes(audio)
                try:
                    normalize(raw, dst)
                except subprocess.CalledProcessError:
                    print(f"  ⚠️  ffmpeg failed for {it.filename}; retrying")
                    continue
            try:
                quality = inspect_audio(dst)
                issues = quality.issues(MIN_DURATION, MIN_PEAK_DB)
            except ValueError as e:
                issues = [str(e)]
            if issues and q < args.quality_retries:
                print(f"  Rejected {it.filename} ({'; '.join(issues)}); resynth {q + 1}")
                continue
            cache[text] = dst.read_bytes()
            written += 1
            ok = True
            break
        if not ok:
            failed += 1
            empties.append(f"{it.filename} ({text})")
            dst.unlink(missing_ok=True)

    print(f"\nDone. {written} written, {skipped} skipped, {failed} failed.")
    if empties:
        print("Could not synthesize (voice returned empty/invalid):")
        for e in empties:
            print(f"  - {e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

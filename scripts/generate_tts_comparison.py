#!/usr/bin/env python3
"""Generate a local, provider-neutral Thai TTS audition pack.

The output is deliberately restricted to scratchpad/tts-comparison so this
experiment cannot overwrite the app's bundled production audio.
"""

import argparse
import html
import json
import os
import shutil
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

from generate_sounds import SoundGenerator


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
SCRATCHPAD_ROOT = PROJECT_ROOT / "scratchpad"
DEFAULT_MANIFEST = SCRIPT_DIR / "tts_comparison_manifest.json"
DEFAULT_OUTPUT = SCRATCHPAD_ROOT / "tts-comparison"
DEFAULT_GOOGLE_VOICES = [
    "th-TH-Neural2-C",
    "th-TH-Chirp3-HD-Aoede",
    "th-TH-Chirp3-HD-Kore",
]
DEFAULT_AZURE_VOICES = [
    "th-TH-PremwadeeNeural",
    "th-TH-AcharaNeural",
    "th-TH-NiwatNeural",
]


def load_manifest(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8") as manifest_file:
        data = json.load(manifest_file)

    items = data.get("items")
    if not isinstance(items, list) or not items:
        raise SystemExit(f"Manifest has no items: {path}")

    required = {"id", "category", "label", "text", "note"}
    ids: set[str] = set()
    for index, item in enumerate(items, start=1):
        if not isinstance(item, dict) or not required.issubset(item):
            missing = sorted(required - set(item if isinstance(item, dict) else {}))
            raise SystemExit(f"Manifest item {index} is missing: {', '.join(missing)}")
        if any(not isinstance(item[key], str) or not item[key] for key in required):
            raise SystemExit(f"Manifest item {index} fields must be non-empty strings")
        item_id = item["id"]
        if not item_id.isascii() or not all(char.isalnum() or char == "-" for char in item_id):
            raise SystemExit(f"Manifest item id must be ASCII letters, digits, or dashes: {item_id}")
        if item_id in ids:
            raise SystemExit(f"Duplicate manifest item id: {item_id}")
        if "ฤ-" in item["text"]:
            raise SystemExit("The intentionally excluded ฤ- form must not be synthesized")
        ids.add(item_id)

    return items


def validated_output_path(raw_path: str) -> Path:
    output = Path(raw_path).expanduser()
    if not output.is_absolute():
        output = PROJECT_ROOT / output
    output = output.resolve()
    scratchpad = SCRATCHPAD_ROOT.resolve()
    if output == scratchpad or scratchpad not in output.parents:
        raise SystemExit(f"Output must be a subdirectory of {scratchpad}")
    return output


def voice_directory(provider: str, voice: str) -> str:
    safe_voice = "".join(char if char.isalnum() or char in "-_" else "-" for char in voice)
    return f"{provider}-{safe_voice}"


def apply_volume_gain(audio_content: bytes, filepath: Path, volume_gain_db: float) -> None:
    filepath.parent.mkdir(parents=True, exist_ok=True)
    if volume_gain_db == 0.0:
        filepath.write_bytes(audio_content)
        return
    if shutil.which("ffmpeg") is None:
        raise SystemExit("--volume-gain-db requires ffmpeg on PATH")

    with tempfile.TemporaryDirectory(prefix="thaisheet-comparison-") as temp_dir:
        source = Path(temp_dir) / "source.mp3"
        output = Path(temp_dir) / "output.mp3"
        source.write_bytes(audio_content)
        try:
            subprocess.run(
                [
                    "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                    "-i", str(source), "-filter:a",
                    f"volume={volume_gain_db:g}dB,alimiter=limit=0.8414:level=false",
                    "-ar", "24000", "-b:a", "64k", str(output),
                ],
                check=True,
            )
        except subprocess.CalledProcessError as error:
            raise SystemExit(f"ffmpeg failed while processing {filepath.name}") from error
        filepath.write_bytes(output.read_bytes())


class AzureGenerator:
    """Generate MP3 files through Azure Speech's REST endpoint."""

    def __init__(
        self,
        *,
        voice: str,
        key: str,
        region: str,
        volume_gain_db: float,
        force: bool,
        dry_run: bool,
        retries: int,
    ) -> None:
        self.voice = voice
        self.key = key
        self.region = region
        self.volume_gain_db = volume_gain_db
        self.force = force
        self.dry_run = dry_run
        self.retries = retries

    def generate(self, text: str, filepath: Path, description: str) -> None:
        if filepath.exists() and not self.force:
            print(f"  Skipping {filepath.name} ({description}; exists)")
            return
        action = "Would generate" if self.dry_run else "Generating"
        print(f"  {action} {filepath.name} ({description})...")
        if self.dry_run:
            return

        escaped_text = html.escape(text)
        escaped_voice = html.escape(self.voice, quote=True)
        ssml = (
            "<speak version='1.0' xml:lang='th-TH'>"
            f"<voice xml:lang='th-TH' name='{escaped_voice}'>{escaped_text}</voice>"
            "</speak>"
        ).encode("utf-8")
        request = urllib.request.Request(
            f"https://{self.region}.tts.speech.microsoft.com/cognitiveservices/v1",
            data=ssml,
            headers={
                "Content-Type": "application/ssml+xml",
                "Ocp-Apim-Subscription-Key": self.key,
                "User-Agent": "ThaiSheet-TTS-Comparison",
                "X-Microsoft-OutputFormat": "audio-24khz-48kbitrate-mono-mp3",
            },
            method="POST",
        )

        for attempt in range(self.retries + 1):
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    audio_content = response.read()
                break
            except urllib.error.HTTPError as error:
                retryable = error.code == 429 or 500 <= error.code < 600
                if retryable and attempt < self.retries:
                    delay = min(2 ** attempt, 30)
                    print(f"  Azure Speech returned HTTP {error.code}; retrying in {delay}s...")
                    time.sleep(delay)
                    continue
                detail = error.read().decode("utf-8", errors="replace")
                raise SystemExit(f"Azure Speech failed with HTTP {error.code}: {detail}") from error
            except urllib.error.URLError as error:
                if attempt < self.retries:
                    delay = min(2 ** attempt, 30)
                    print(f"  Azure Speech is unavailable; retrying in {delay}s...")
                    time.sleep(delay)
                    continue
                raise SystemExit(f"Azure Speech request failed: {error.reason}") from error

        apply_volume_gain(audio_content, filepath, self.volume_gain_db)


def generate_google(
    items: list[dict[str, str]],
    voices: list[str],
    output: Path,
    args: argparse.Namespace,
) -> list[tuple[str, str]]:
    columns = []
    for voice in voices:
        directory = voice_directory("google", voice)
        columns.append((f"Google {voice}", directory))
        print(f"\n[Google: {voice}]")
        generator = SoundGenerator(
            language_code="th-TH",
            voice_name=voice,
            speaking_rate=1.0,
            pitch=0.0,
            volume_gain_db=args.volume_gain_db,
            force=args.force,
            dry_run=args.dry_run,
            retries=args.retries,
            retry_delay=2.0,
        )
        target = output / directory
        target.mkdir(parents=True, exist_ok=True)
        for item in items:
            generator.generate(item["text"], target / f"{item['id']}.mp3", item["label"])
    return columns


def generate_azure(
    items: list[dict[str, str]],
    voices: list[str],
    output: Path,
    args: argparse.Namespace,
) -> list[tuple[str, str]]:
    key = os.environ.get("AZURE_SPEECH_KEY", "")
    region = os.environ.get("AZURE_SPEECH_REGION", "")
    if not args.dry_run and (not key or not region):
        raise SystemExit(
            "Azure generation requires AZURE_SPEECH_KEY and AZURE_SPEECH_REGION. "
            "Use --dry-run to inspect the pack without credentials."
        )

    columns = []
    for voice in voices:
        directory = voice_directory("azure", voice)
        columns.append((f"Azure {voice}", directory))
        print(f"\n[Azure: {voice}]")
        generator = AzureGenerator(
            voice=voice,
            key=key,
            region=region,
            volume_gain_db=args.volume_gain_db,
            force=args.force,
            dry_run=args.dry_run,
            retries=args.retries,
        )
        target = output / directory
        target.mkdir(parents=True, exist_ok=True)
        for item in items:
            generator.generate(item["text"], target / f"{item['id']}.mp3", item["label"])
    return columns


def write_index(
    output: Path,
    items: list[dict[str, str]],
    columns: list[tuple[str, str]],
    volume_gain_db: float,
) -> None:
    category = None
    rows = []
    for item in items:
        if item["category"] != category:
            category = item["category"]
            rows.append(
                f'<tr class="category"><th colspan="{len(columns) + 1}">{html.escape(category)}</th></tr>'
            )

        audio_cells = []
        for _, directory in columns:
            relative_path = f"{directory}/{item['id']}.mp3"
            if (output / relative_path).exists():
                audio_cells.append(
                    f'<td><audio controls preload="none" '
                    f'src="{html.escape(relative_path)}"></audio></td>'
                )
            else:
                audio_cells.append('<td class="missing">Not generated</td>')
        rows.append(
            "<tr>"
            f"<th><strong lang='th'>{html.escape(item['label'])}</strong>"
            f"<code lang='th'>{html.escape(item['text'])}</code>"
            f"<span>{html.escape(item['note'])}</span></th>"
            f"{''.join(audio_cells)}"
            "</tr>"
        )

    headers = "".join(f"<th>{html.escape(label)}</th>" for label, _ in columns)
    document = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>ThaiSheet TTS comparison</title>
  <style>
    :root {{ color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }}
    body {{ margin: 0; background: Canvas; color: CanvasText; }}
    header {{ padding: 24px max(20px, calc((100vw - 1440px) / 2)); border-bottom: 1px solid color-mix(in srgb, CanvasText 18%, transparent); }}
    h1 {{ margin: 0 0 8px; font-size: 24px; letter-spacing: 0; }}
    p {{ margin: 0; color: color-mix(in srgb, CanvasText 68%, transparent); }}
    main {{ overflow-x: auto; padding: 20px; }}
    table {{ width: min-content; min-width: 100%; border-collapse: collapse; }}
    th, td {{ padding: 14px; border-bottom: 1px solid color-mix(in srgb, CanvasText 14%, transparent); text-align: left; vertical-align: middle; }}
    thead th {{ position: sticky; top: 0; background: Canvas; min-width: 290px; z-index: 1; }}
    thead th:first-child {{ min-width: 240px; }}
    tbody th {{ font-weight: 400; }}
    tbody strong {{ display: block; font-size: 23px; letter-spacing: 0; }}
    code {{ display: inline-block; margin-top: 5px; font-size: 15px; }}
    tbody span {{ display: block; max-width: 320px; margin-top: 7px; color: color-mix(in srgb, CanvasText 62%, transparent); font-size: 13px; line-height: 1.35; }}
    .category th {{ padding-top: 28px; background: color-mix(in srgb, CanvasText 7%, Canvas); font-size: 17px; font-weight: 700; }}
    audio {{ display: block; width: 270px; }}
    .missing {{ color: color-mix(in srgb, CanvasText 45%, transparent); font-size: 13px; }}
  </style>
</head>
<body>
  <header>
    <h1>ThaiSheet TTS comparison</h1>
    <p>All candidates use the exact Thai synthesis text shown in monospace and receive the same {volume_gain_db:g} dB post-synthesis gain.</p>
  </header>
  <main>
    <table>
      <thead><tr><th>Test item</th>{headers}</tr></thead>
      <tbody>{''.join(rows)}</tbody>
    </table>
  </main>
  <script>
    document.addEventListener('play', event => {{
      if (event.target.tagName !== 'AUDIO') return;
      document.querySelectorAll('audio').forEach(audio => {{
        if (audio !== event.target) audio.pause();
      }});
    }}, true);
  </script>
</body>
</html>
"""
    (output / "index.html").write_text(document, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a local Thai TTS provider comparison pack")
    parser.add_argument("--provider", choices=["google", "azure"], action="append")
    parser.add_argument("--google-voice", action="append", help="Google voice name; may be repeated")
    parser.add_argument("--azure-voice", action="append", help="Azure voice name; may be repeated")
    parser.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--volume-gain-db", type=float, default=6.0)
    parser.add_argument("--retries", type=int, default=3)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not -96.0 <= args.volume_gain_db <= 16.0:
        parser.error("--volume-gain-db must be between -96.0 and 16.0")
    if args.retries < 0:
        parser.error("--retries must be 0 or greater")

    providers = args.provider or ["google"]
    google_voices = args.google_voice or DEFAULT_GOOGLE_VOICES
    azure_voices = args.azure_voice or DEFAULT_AZURE_VOICES
    if "azure" in providers and not args.dry_run:
        if not os.environ.get("AZURE_SPEECH_KEY") or not os.environ.get("AZURE_SPEECH_REGION"):
            parser.error(
                "Azure generation requires AZURE_SPEECH_KEY and AZURE_SPEECH_REGION; "
                "use --dry-run to inspect it without credentials"
            )
    output = validated_output_path(args.output)
    items = load_manifest(Path(args.manifest).expanduser().resolve())
    output.mkdir(parents=True, exist_ok=True)

    print(f"Output directory: {output}")
    print(f"Manifest items: {len(items)}")
    print(f"Volume gain: {args.volume_gain_db:g} dB")

    columns: list[tuple[str, str]] = []
    if "google" in providers:
        columns.extend(generate_google(items, google_voices, output, args))
    if "azure" in providers:
        columns.extend(generate_azure(items, azure_voices, output, args))

    write_index(output, items, columns, args.volume_gain_db)
    print(f"\nAudition page: {output / 'index.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

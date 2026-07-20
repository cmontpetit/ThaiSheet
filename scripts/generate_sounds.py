#!/usr/bin/env python3
"""
Generate Thai cheat sheet sound files using Google Cloud Text-to-Speech.

Usage:
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    gcloud auth application-default login

    # Preview what would be generated without calling the API
    python3 generate_sounds.py --all --dry-run --check-files

    # Regenerate all sounds, replacing existing files
    python3 generate_sounds.py --all --force --check-files

    # Generate specific types
    python3 generate_sounds.py --tone-marks
    python3 generate_sounds.py --tone-rules
    python3 generate_sounds.py --consonants
    python3 generate_sounds.py --vowels
    python3 generate_sounds.py --sample-words

Output files are saved to ThaiSheet/Resources/sounds/
"""

import argparse
from dataclasses import dataclass
import re
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

from sound_inventory import (
    SOUND_TYPE_LABELS,
    SOUND_TYPE_ORDER,
    SoundItem,
    bundled_voice_filename,
    expected_bundled_filenames,
    inventory_by_type,
    load_sound_inventory,
)


DEFAULT_LANGUAGE_CODE = "th-TH"
DEFAULT_VOICE_NAME = "th-TH-Neural2-C"


def get_project_paths():
    """Get project root and sounds directory paths."""
    script_dir = Path(__file__).parent.absolute()
    project_root = script_dir.parent
    sounds_dir = project_root / "ThaiSheet" / "Resources" / "sounds"
    cheatsheet_dir = project_root / "ThaiSheet" / "Resources" / "cheatsheet"
    return project_root, sounds_dir, cheatsheet_dir


@dataclass(frozen=True)
class AudioQuality:
    duration_seconds: float
    max_volume_db: float

    def issues(self, minimum_duration: float, minimum_peak_db: float) -> list[str]:
        issues = []
        if self.duration_seconds < minimum_duration:
            issues.append(f"duration {self.duration_seconds:.3f}s < {minimum_duration:.3f}s")
        if self.max_volume_db < minimum_peak_db:
            issues.append(f"peak {self.max_volume_db:.1f} dB < {minimum_peak_db:.1f} dB")
        return issues


def inspect_audio(filepath: Path) -> AudioQuality:
    """Measure duration and peak level with FFprobe/FFmpeg."""
    try:
        duration_result = subprocess.run(
            [
                "ffprobe", "-v", "error", "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1", str(filepath),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        volume_result = subprocess.run(
            [
                "ffmpeg", "-hide_banner", "-nostats", "-i", str(filepath),
                "-af", "volumedetect", "-f", "null", "-",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
    except (subprocess.CalledProcessError, ValueError) as error:
        raise ValueError(f"could not inspect {filepath.name}") from error

    max_volume_match = re.search(r"max_volume:\s*(-?(?:inf|\d+(?:\.\d+)?)) dB", volume_result.stderr)
    if not max_volume_match:
        raise ValueError(f"could not read peak level for {filepath.name}")
    max_volume_text = max_volume_match.group(1)
    max_volume = float("-inf") if max_volume_text == "-inf" else float(max_volume_text)
    return AudioQuality(float(duration_result.stdout.strip()), max_volume)


class SoundGenerator:
    """Generate MP3 files with Google Cloud Text-to-Speech."""

    def __init__(
        self,
        *,
        language_code: str,
        voice_name: str,
        speaking_rate: float,
        pitch: float,
        volume_gain_db: float,
        force: bool,
        dry_run: bool,
        retries: int,
        retry_delay: float,
        normalize_lufs: float | None = None,
        quality_retries: int = 4,
        minimum_duration: float = 0.35,
        minimum_peak_db: float = -24.0,
        quality_check: bool = True,
    ) -> None:
        self.force = force
        self.dry_run = dry_run
        self.retries = retries
        self.retry_delay = retry_delay
        self.volume_gain_db = volume_gain_db
        self.normalize_lufs = normalize_lufs
        self.quality_retries = quality_retries
        self.minimum_duration = minimum_duration
        self.minimum_peak_db = minimum_peak_db
        self.quality_check = quality_check
        self.written = 0
        self.skipped = 0
        self.expected_files: set[Path] = set()
        self.quality_results: dict[str, AudioQuality] = {}
        self.processed_audio_by_text: dict[str, bytes] = {}
        self.quality_by_text: dict[str, AudioQuality | None] = {}

        self.texttospeech = None
        self.client = None
        self.voice = None
        self.audio_config = None
        self.google_exceptions = None

        if dry_run:
            return

        required_tools = []
        if quality_check or volume_gain_db != 0.0 or normalize_lufs is not None:
            required_tools.append("ffmpeg")
        if quality_check:
            required_tools.append("ffprobe")
        missing_tools = [tool for tool in required_tools if shutil.which(tool) is None]
        if missing_tools:
            raise SystemExit(f"Audio generation requires these tools on PATH: {', '.join(missing_tools)}")

        try:
            from google.cloud import texttospeech
            from google.api_core import exceptions as google_exceptions
        except ImportError as error:
            raise SystemExit(
                "Missing google-cloud-texttospeech. Run: "
                "cd scripts && python3 -m venv venv && source venv/bin/activate "
                "&& pip install -r requirements.txt"
            ) from error

        self.texttospeech = texttospeech
        self.google_exceptions = google_exceptions
        self.client = texttospeech.TextToSpeechClient()
        voice_args = {"language_code": language_code}
        if voice_name:
            voice_args["name"] = voice_name
        self.voice = texttospeech.VoiceSelectionParams(**voice_args)

        audio_config_args = {"audio_encoding": texttospeech.AudioEncoding.MP3}
        if speaking_rate != 1.0:
            audio_config_args["speaking_rate"] = speaking_rate
        if pitch != 0.0:
            audio_config_args["pitch"] = pitch
        self.audio_config = texttospeech.AudioConfig(**audio_config_args)

    def generate(self, text: str, filepath: Path, description: str = "") -> None:
        """Generate a single sound file."""
        desc = f" ({description})" if description else ""
        self.expected_files.add(filepath)

        if filepath.exists() and not self.force:
            print(f"  Skipping {filepath.name}{desc} (exists; pass --force to overwrite)")
            self.skipped += 1
            return

        action = "Would generate" if self.dry_run else "Generating"
        print(f"  {action} {filepath.name}{desc}...")

        if self.dry_run:
            self.written += 1
            return

        assert self.texttospeech is not None
        assert self.client is not None
        assert self.voice is not None
        assert self.audio_config is not None
        assert self.google_exceptions is not None
        filepath.parent.mkdir(parents=True, exist_ok=True)

        cached_audio = self.processed_audio_by_text.get(text)
        if cached_audio is not None:
            filepath.write_bytes(cached_audio)
            quality = self.quality_by_text[text]
            if quality is not None:
                self.quality_results[filepath.name] = quality
            print(f"  Reused processed audio for identical input: {text}")
            self.written += 1
            return

        with tempfile.TemporaryDirectory(prefix="thaisheet-audio-") as temp_dir:
            source = Path(temp_dir) / "source.mp3"
            for quality_attempt in range(self.quality_retries + 1):
                response = self.synthesize(text)
                source.write_bytes(response.audio_content)
                issues = []
                if self.quality_check:
                    try:
                        quality = inspect_audio(source)
                        issues = quality.issues(self.minimum_duration, self.minimum_peak_db)
                    except ValueError as error:
                        quality = None
                        issues = [str(error)]
                else:
                    quality = None

                if not issues:
                    if quality is not None:
                        self.quality_results[filepath.name] = quality
                    self.write_processed_audio(source, filepath)
                    self.processed_audio_by_text[text] = filepath.read_bytes()
                    self.quality_by_text[text] = quality
                    self.written += 1
                    return

                issue_text = "; ".join(issues)
                if quality_attempt < self.quality_retries:
                    print(
                        f"  Rejected {filepath.name} ({issue_text}); "
                        f"resynthesizing ({quality_attempt + 1}/{self.quality_retries})..."
                    )
                    continue
                raise SystemExit(
                    f"Audio quality check failed for {filepath.name} after "
                    f"{self.quality_retries + 1} attempts: {issue_text}"
                )

    def synthesize(self, text: str):
        synthesis_input = self.texttospeech.SynthesisInput(text=text)
        for attempt in range(self.retries + 1):
            try:
                return self.client.synthesize_speech(
                    input=synthesis_input,
                    voice=self.voice,
                    audio_config=self.audio_config,
                )
            except self.google_exceptions.PermissionDenied as error:
                if is_service_disabled_error(error) and attempt < self.retries:
                    self.retry_after_delay(error, attempt)
                    continue
                raise SystemExit(format_permission_error(error)) from error
            except self.google_exceptions.GoogleAPICallError as error:
                if is_retryable_google_api_error(error) and attempt < self.retries:
                    self.retry_after_delay(error, attempt)
                    continue
                raise SystemExit(format_google_api_error(error)) from error

    def write_processed_audio(self, source: Path, filepath: Path) -> None:
        """Write an MP3, optionally normalizing or applying peak-limited gain."""
        if self.normalize_lufs is None and self.volume_gain_db == 0.0:
            shutil.copyfile(source, filepath)
            return

        if self.normalize_lufs is not None:
            audio_filter = f"loudnorm=I={self.normalize_lufs:g}:LRA=7:TP=-1.5"
        else:
            audio_filter = f"volume={self.volume_gain_db:g}dB,alimiter=limit=0.8414:level=false"
        try:
            subprocess.run(
                [
                    "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                    "-i", str(source), "-filter:a", audio_filter,
                    "-ar", "24000", "-b:a", "64k", str(filepath),
                ],
                check=True,
            )
        except subprocess.CalledProcessError as error:
            raise SystemExit(f"ffmpeg failed while processing {filepath.name}") from error

    def retry_after_delay(self, error: Exception, attempt: int) -> None:
        delay = min(self.retry_delay * (2 ** attempt), 60.0)
        print(f"  Google Cloud TTS is not ready yet ({short_error(error)}). Retrying in {delay:g}s...")
        time.sleep(delay)


def format_permission_error(error: Exception) -> str:
    """Return a short actionable message for common Google Cloud permission errors."""
    message = str(error)
    activation_url = find_activation_url(message)
    project_id = find_project_id(message)

    lines = [
        "Google Cloud Text-to-Speech permission error.",
        "",
        "Most likely fix: enable the Cloud Text-to-Speech API for the Google Cloud project used by your Application Default Credentials.",
    ]

    if project_id:
        lines.extend([
            "",
            "Command:",
            f"  gcloud services enable texttospeech.googleapis.com --project {project_id}",
            f"  gcloud auth application-default set-quota-project {project_id}",
        ])

    if activation_url:
        lines.extend([
            "",
            "Console link:",
            f"  {activation_url}",
        ])

    lines.extend([
        "",
        "If you enabled the API recently, wait a few minutes and retry.",
        "",
        f"Original error: {message}",
    ])
    return "\n".join(lines)


def format_google_api_error(error: Exception) -> str:
    """Return a short actionable message for Google Cloud API errors."""
    return "\n".join([
        "Google Cloud Text-to-Speech API call failed.",
        "",
        "Check that billing is enabled, the API is enabled, and your Application Default Credentials are for the intended project.",
        "",
        f"Original error: {error}",
    ])


def is_service_disabled_error(error: Exception) -> bool:
    message = str(error)
    return "SERVICE_DISABLED" in message or "has not been used" in message


def is_retryable_google_api_error(error: Exception) -> bool:
    message = str(error)
    return any(token in message for token in [
        "DEADLINE_EXCEEDED",
        "RESOURCE_EXHAUSTED",
        "UNAVAILABLE",
        "failed to connect",
        "No route to host",
        "503",
    ])


def short_error(error: Exception) -> str:
    first_line = str(error).splitlines()[0]
    return first_line[:160]


def find_activation_url(message: str) -> str | None:
    match = re.search(
        r"https://console\.developers\.google\.com/apis/api/texttospeech\.googleapis\.com/overview\?project=[\w-]+",
        message,
    )
    return match.group(0) if match else None


def find_project_id(message: str) -> str | None:
    match = re.search(r"project ([a-z][a-z0-9-]{4,}[a-z0-9])", message)
    return match.group(1) if match else None


def generate_sound_type(
    sounds_dir: Path,
    items: list[SoundItem],
    sound_type: str,
    generator: SoundGenerator,
    bundled_voice_key: str | None,
) -> None:
    selected_items = [item for item in items if item.sound_type == sound_type]
    print(f"\n[{SOUND_TYPE_LABELS[sound_type]}]")
    for item in selected_items:
        generator.generate(
            item.synthesis_text,
            sounds_dir / output_filename(item, bundled_voice_key),
            item.description,
        )
    print(f"  Processed {len(selected_items)} sounds")


def output_filename(item: SoundItem, bundled_voice_key: str | None) -> str:
    if bundled_voice_key is None:
        return item.filename
    return bundled_voice_filename(item.filename, bundled_voice_key)


def check_sound_files(sounds_dir: Path, expected_filenames: set[str]) -> bool:
    """Check that bundled MP3s match the files generated from current JSON data."""
    existing_files = {path.name for path in sounds_dir.glob("*.mp3")}
    stale_files = sorted(existing_files - expected_filenames)
    missing_files = sorted(expected_filenames - existing_files)

    if not stale_files and not missing_files:
        print("\nSound file check passed.")
        return True

    if stale_files:
        print("\nStale MP3 files not generated from current JSON data:")
        for path in stale_files:
            print(f"  {path.name}")

    if missing_files:
        print("\nMissing expected MP3 files:")
        for path in missing_files:
            print(f"  {path.name}")

    return False


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Generate Thai cheat sheet sound files using Google Cloud Text-to-Speech'
    )
    parser.add_argument('--all', action='store_true', help='Generate all sounds')
    parser.add_argument('--tone-marks', action='store_true', help='Generate tone mark sounds')
    parser.add_argument('--tone-rules', action='store_true', help='Generate tone rule sample word sounds')
    parser.add_argument('--consonants', action='store_true', help='Generate consonant sounds')
    parser.add_argument('--vowels', action='store_true', help='Generate vowel sounds')
    parser.add_argument('--clusters', action='store_true', help='Generate cluster sounds')
    parser.add_argument('--sample-words', action='store_true', help='Generate reference sample word sounds')
    parser.add_argument('--sound-id', action='append', help='Generate one stable inventory ID; may be repeated')
    parser.add_argument('--language-code', default=DEFAULT_LANGUAGE_CODE, help='Google Cloud TTS language code')
    parser.add_argument('--voice-name', default=DEFAULT_VOICE_NAME, help='Google Cloud TTS voice name')
    parser.add_argument('--speaking-rate', type=float, default=1.0, help='Speaking rate, where 1.0 is normal')
    parser.add_argument('--pitch', type=float, default=0.0, help='Speaking pitch in semitones')
    parser.add_argument(
        '--volume-gain-db', type=float, default=0.0,
        help='Legacy post-synthesis gain in dB; output is peak-limited to -1.5 dB',
    )
    parser.add_argument(
        '--normalize-lufs', type=float,
        help='Normalize output loudness to this LUFS target with a -1.5 dB true-peak limit',
    )
    parser.add_argument(
        '--output-dir',
        help='Candidate output directory; custom paths must be beneath the project scratchpad',
    )
    parser.add_argument('--force', action='store_true', help='Overwrite existing MP3 files')
    parser.add_argument('--dry-run', action='store_true', help='Show files that would be generated without calling the API')
    parser.add_argument('--check-files', action='store_true', help='Fail if output MP3s are stale or missing')
    parser.add_argument('--retries', type=int, default=4, help='Retries for transient Google Cloud API errors')
    parser.add_argument('--retry-delay', type=float, default=5.0, help='Initial retry delay in seconds')
    parser.add_argument('--quality-retries', type=int, default=4, help='Resynthesis attempts for rejected audio')
    parser.add_argument('--minimum-duration', type=float, default=0.35, help='Minimum accepted duration in seconds')
    parser.add_argument('--minimum-peak-db', type=float, default=-24.0, help='Minimum accepted peak level in dBFS')
    parser.add_argument('--skip-quality-check', action='store_true', help='Accept synthesized audio without acoustic validation')

    args = parser.parse_args()
    selected_types = [
        args.tone_marks, args.tone_rules, args.consonants, args.vowels,
        args.clusters, args.sample_words,
    ]

    if args.sound_id and any([args.all, *selected_types]):
        parser.error("--sound-id cannot be combined with sound type options")

    if args.retries < 0:
        parser.error("--retries must be 0 or greater")

    if args.retry_delay < 0:
        parser.error("--retry-delay must be 0 or greater")

    if args.quality_retries < 0:
        parser.error("--quality-retries must be 0 or greater")

    if args.minimum_duration <= 0:
        parser.error("--minimum-duration must be greater than 0")

    if not -96.0 <= args.volume_gain_db <= 16.0:
        parser.error("--volume-gain-db must be between -96.0 and 16.0")

    if args.normalize_lufs is not None and not -70.0 <= args.normalize_lufs <= -5.0:
        parser.error("--normalize-lufs must be between -70 and -5")

    if args.normalize_lufs is not None and args.volume_gain_db != 0.0:
        parser.error("--normalize-lufs and --volume-gain-db cannot be used together")

    if args.check_files and (args.sound_id or (not args.all and any(selected_types))):
        parser.error("--check-files must be used with --all or with no specific sound type")

    # Default to --all if no specific option provided
    if not any([args.all, args.sound_id, *selected_types]):
        args.all = True

    project_root, production_sounds_dir, cheatsheet_dir = get_project_paths()
    if args.output_dir:
        sounds_dir = Path(args.output_dir).expanduser()
        if not sounds_dir.is_absolute():
            sounds_dir = project_root / sounds_dir
        sounds_dir = sounds_dir.resolve()
        scratchpad_dir = (project_root / "scratchpad").resolve()
        if sounds_dir == scratchpad_dir or scratchpad_dir not in sounds_dir.parents:
            parser.error(f"--output-dir must be beneath {scratchpad_dir}")
    else:
        sounds_dir = production_sounds_dir

    # Candidate directories contain one isolated, voice-neutral set. Production
    # filenames carry the explicit Neural2 suffix alongside Kore and Matilda.
    bundled_voice_key = "neural2" if sounds_dir == production_sounds_dir else None

    if sounds_dir == production_sounds_dir and not sounds_dir.exists():
        print(f"Error: Sounds directory not found: {sounds_dir}")
        return 1
    sounds_dir.mkdir(parents=True, exist_ok=True)

    inventory = load_sound_inventory(cheatsheet_dir)
    grouped_inventory = inventory_by_type(inventory)
    if args.sound_id:
        inventory_ids = {item.id for item in inventory}
        unknown_ids = sorted(set(args.sound_id) - inventory_ids)
        if unknown_ids:
            parser.error(f"unknown --sound-id values: {', '.join(unknown_ids)}")

    print(f"Output directory: {sounds_dir}")
    print(f"Voice: {args.voice_name or '(default for language)'} ({args.language_code})")
    if args.normalize_lufs is not None:
        print(f"Loudness normalization: {args.normalize_lufs:g} LUFS, -1.5 dB peak limit")
    else:
        print(f"Volume gain: {args.volume_gain_db:g} dB")
    if args.skip_quality_check:
        print("Audio quality validation: disabled")
    else:
        print(
            f"Audio quality validation: at least {args.minimum_duration:g}s and "
            f"{args.minimum_peak_db:g} dBFS peak; {args.quality_retries} retries"
        )
    if not args.force:
        print("Existing files will be skipped; pass --force to overwrite them.")

    generator = SoundGenerator(
        language_code=args.language_code,
        voice_name=args.voice_name,
        speaking_rate=args.speaking_rate,
        pitch=args.pitch,
        volume_gain_db=args.volume_gain_db,
        force=args.force,
        dry_run=args.dry_run,
        retries=args.retries,
        retry_delay=args.retry_delay,
        normalize_lufs=args.normalize_lufs,
        quality_retries=args.quality_retries,
        minimum_duration=args.minimum_duration,
        minimum_peak_db=args.minimum_peak_db,
        quality_check=not args.skip_quality_check,
    )

    if args.sound_id:
        selected_ids = set(args.sound_id)
        selected_items = [item for item in inventory if item.id in selected_ids]
        print("\n[Selected sounds]")
        for item in selected_items:
            generator.generate(
                item.synthesis_text,
                sounds_dir / output_filename(item, bundled_voice_key),
                item.description,
            )
        print(f"  Processed {len(selected_items)} sounds")
    else:
        selected_sound_types = {
            "tone_mark": args.all or args.tone_marks,
            "tone_rule": args.all or args.tone_rules,
            "consonant": args.all or args.consonants,
            "vowel": args.all or args.vowels,
            "cluster": args.all or args.clusters,
            "sample_word": args.all or args.sample_words,
        }
        for sound_type in SOUND_TYPE_ORDER:
            if selected_sound_types[sound_type]:
                generate_sound_type(
                    sounds_dir,
                    grouped_inventory[sound_type],
                    sound_type,
                    generator,
                    bundled_voice_key,
                )

    action = "would be generated" if args.dry_run else "written"
    print(f"\nDone! {generator.written} files {action}; {generator.skipped} skipped.")

    if args.check_files:
        expected_filenames = (
            expected_bundled_filenames(inventory)
            if bundled_voice_key is not None
            else {item.filename for item in inventory}
        )
        if not check_sound_files(sounds_dir, expected_filenames):
            return 1

    return 0


if __name__ == "__main__":
    exit(main())

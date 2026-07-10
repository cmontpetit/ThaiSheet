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

Output files are saved to ThaiSheet/Resources/sounds/
"""

import argparse
import json
import re
from pathlib import Path


DEFAULT_LANGUAGE_CODE = "th-TH"
DEFAULT_VOICE_NAME = "th-TH-Neural2-C"


def get_project_paths():
    """Get project root and sounds directory paths."""
    script_dir = Path(__file__).parent.absolute()
    project_root = script_dir.parent
    sounds_dir = project_root / "ThaiSheet" / "Resources" / "sounds"
    cheatsheet_dir = project_root / "ThaiSheet" / "Resources" / "cheatsheet"
    return project_root, sounds_dir, cheatsheet_dir


class SoundGenerator:
    """Generate MP3 files with Google Cloud Text-to-Speech."""

    def __init__(
        self,
        *,
        language_code: str,
        voice_name: str,
        speaking_rate: float,
        pitch: float,
        force: bool,
        dry_run: bool,
    ) -> None:
        self.force = force
        self.dry_run = dry_run
        self.written = 0
        self.skipped = 0
        self.expected_files: set[Path] = set()

        self.texttospeech = None
        self.client = None
        self.voice = None
        self.audio_config = None
        self.google_exceptions = None

        if dry_run:
            return

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
        synthesis_input = self.texttospeech.SynthesisInput(text=text)
        try:
            response = self.client.synthesize_speech(
                input=synthesis_input,
                voice=self.voice,
                audio_config=self.audio_config,
            )
        except self.google_exceptions.PermissionDenied as error:
            raise SystemExit(format_permission_error(error)) from error
        except self.google_exceptions.GoogleAPICallError as error:
            raise SystemExit(format_google_api_error(error)) from error

        filepath.write_bytes(response.audio_content)
        self.written += 1


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


def find_activation_url(message: str) -> str | None:
    match = re.search(
        r"https://console\.developers\.google\.com/apis/api/texttospeech\.googleapis\.com/overview\?project=[\w-]+",
        message,
    )
    return match.group(0) if match else None


def find_project_id(message: str) -> str | None:
    match = re.search(r"project ([a-z][a-z0-9-]{4,}[a-z0-9])", message)
    return match.group(1) if match else None


# =============================================================================
# TONE MARKS
# =============================================================================

def generate_tone_marks(sounds_dir: Path, cheatsheet_dir: Path, generator: SoundGenerator) -> None:
    """Generate tone mark sound files using fixed consonants matching the reference.

    Uses ค (low class) and ก (mid class) to match the reference display.
    Generates 8 total files: 3 for low class + 5 for mid/high class.
    """
    print("\n[Tone Marks]")

    # Load tone marks
    tone_marks_path = cheatsheet_dir / "tone-marks.json"
    with open(tone_marks_path, 'r', encoding='utf-8') as f:
        tone_marks_data = json.load(f)

    # Fixed consonants matching the reference
    LOW_CONSONANT = "ค"      # Used for low class examples
    MID_CONSONANT = "ก"      # Used for mid/high class examples

    count = 0
    for tone_mark in tone_marks_data['toneMarks']:
        mark = tone_mark['mark']
        on_low = tone_mark['onLowConsonant']
        on_mid_high = tone_mark['onMidHighConsonant']

        # Generate low class sound (using ค)
        if on_low != 'n/a':
            display = LOW_CONSONANT + mark + "า"
            filename = f"cheat_sheet_tone_mark_{display}.mp3"
            generator.generate(display, sounds_dir / filename, f"{on_low} tone (low class)")
            count += 1

        # Generate mid/high class sound (using ก)
        if on_mid_high != 'n/a':
            display = MID_CONSONANT + mark + "า"
            filename = f"cheat_sheet_tone_mark_{display}.mp3"
            generator.generate(display, sounds_dir / filename, f"{on_mid_high} tone (mid/high class)")
            count += 1

    print(f"  Processed {count} tone mark sounds")


# =============================================================================
# TONE RULES
# =============================================================================

def generate_tone_rules(sounds_dir: Path, cheatsheet_dir: Path, generator: SoundGenerator) -> None:
    """Generate tone rule sample word sound files."""
    print("\n[Tone Rules]")

    json_path = cheatsheet_dir / "tone-rules.json"
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    count = 0
    seen = set()  # Avoid duplicates across rules

    for rule in data['toneRules']:
        if 'samples' in rule and rule['samples']:
            tone = rule['tone']
            # Generate sound for all samples in the rule
            for sample in rule['samples']:
                word = sample['full']
                if word not in seen:
                    seen.add(word)
                    filename = f"cheat_sheet_tone_rule_{word}.mp3"
                    generator.generate(word, sounds_dir / filename, f"{tone} tone")
                    count += 1

    print(f"  Processed {count} tone rule sounds")


# =============================================================================
# CONSONANTS
# =============================================================================

def generate_consonants(sounds_dir: Path, cheatsheet_dir: Path, generator: SoundGenerator) -> None:
    """Generate consonant sound files."""
    print("\n[Consonants]")

    json_path = cheatsheet_dir / "consonants.json"
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    count = 0
    for consonant in data['consonants']:
        char = consonant['character']
        name = consonant['name']
        # Use the full name for pronunciation (e.g., "กอ ไก่")
        filename = f"cheat_sheet_consonant_{char}.mp3"
        generator.generate(name, sounds_dir / filename, name)
        count += 1

    print(f"  Processed {count} consonant sounds")


# =============================================================================
# VOWELS
# =============================================================================

def generate_vowels(sounds_dir: Path, cheatsheet_dir: Path, generator: SoundGenerator) -> None:
    """Generate vowel sound files."""
    print("\n[Vowels]")

    json_path = cheatsheet_dir / "vowels.json"
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    count = 0
    seen = set()  # Avoid duplicates

    for vowel in data['vowels']:
        # Generate sound for each vowel form (short/long, open/closed)
        forms = [
            vowel['short'].get('closed'),
            vowel['short'].get('open'),
            vowel['long'].get('closed'),
            vowel['long'].get('open'),
        ]

        for form in forms:
            if form and form not in seen:
                seen.add(form)
                # Remove trailing dash for pronunciation
                text = form.rstrip('-')
                filename = f"cheat_sheet_vowel_{form}.mp3"
                generator.generate(text, sounds_dir / filename)
                count += 1

    print(f"  Processed {count} vowel sounds")


# =============================================================================
# CLUSTERS
# =============================================================================

def generate_clusters(sounds_dir: Path, cheatsheet_dir: Path, generator: SoundGenerator) -> None:
    """Generate cluster sound files using cluster + า."""
    print("\n[Clusters]")

    json_path = cheatsheet_dir / "clusters.json"
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    count = 0
    for cluster in data['clusters']:
        cluster_text = cluster['cluster']
        # Match Cluster.displayWithVowel in the app.
        # e.g., "กร-" -> "กรา", but final-position "-ทร" stays as written.
        if cluster_text.startswith('-'):
            display = cluster_text
        else:
            base = cluster_text.strip('-')
            display = base + "า"

        filename = f"cheat_sheet_cluster_{display}.mp3"
        sound_type = cluster.get('type', '')
        generator.generate(display, sounds_dir / filename, sound_type)
        count += 1

    print(f"  Processed {count} cluster sounds")


def check_sound_files(sounds_dir: Path, generator: SoundGenerator) -> bool:
    """Check that bundled MP3s match the files generated from current JSON data."""
    existing_files = set(sounds_dir.glob("*.mp3"))
    stale_files = sorted(existing_files - generator.expected_files)
    missing_files = sorted(generator.expected_files - existing_files)

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
    parser.add_argument('--language-code', default=DEFAULT_LANGUAGE_CODE, help='Google Cloud TTS language code')
    parser.add_argument('--voice-name', default=DEFAULT_VOICE_NAME, help='Google Cloud TTS voice name')
    parser.add_argument('--speaking-rate', type=float, default=1.0, help='Speaking rate, where 1.0 is normal')
    parser.add_argument('--pitch', type=float, default=0.0, help='Speaking pitch in semitones')
    parser.add_argument('--force', action='store_true', help='Overwrite existing MP3 files')
    parser.add_argument('--dry-run', action='store_true', help='Show files that would be generated without calling the API')
    parser.add_argument('--check-files', action='store_true', help='Fail if bundled MP3s are stale or missing')

    args = parser.parse_args()
    selected_types = [args.tone_marks, args.tone_rules, args.consonants, args.vowels, args.clusters]

    if args.check_files and not args.all and any(selected_types):
        parser.error("--check-files must be used with --all or with no specific sound type")

    # Default to --all if no specific option provided
    if not any([args.all, *selected_types]):
        args.all = True

    project_root, sounds_dir, cheatsheet_dir = get_project_paths()

    if not sounds_dir.exists():
        print(f"Error: Sounds directory not found: {sounds_dir}")
        return 1

    print(f"Output directory: {sounds_dir}")
    print(f"Voice: {args.voice_name or '(default for language)'} ({args.language_code})")
    if not args.force:
        print("Existing files will be skipped; pass --force to overwrite them.")

    generator = SoundGenerator(
        language_code=args.language_code,
        voice_name=args.voice_name,
        speaking_rate=args.speaking_rate,
        pitch=args.pitch,
        force=args.force,
        dry_run=args.dry_run,
    )

    if args.all or args.tone_marks:
        generate_tone_marks(sounds_dir, cheatsheet_dir, generator)

    if args.all or args.tone_rules:
        generate_tone_rules(sounds_dir, cheatsheet_dir, generator)

    if args.all or args.consonants:
        generate_consonants(sounds_dir, cheatsheet_dir, generator)

    if args.all or args.vowels:
        generate_vowels(sounds_dir, cheatsheet_dir, generator)

    if args.all or args.clusters:
        generate_clusters(sounds_dir, cheatsheet_dir, generator)

    action = "would be generated" if args.dry_run else "written"
    print(f"\nDone! {generator.written} files {action}; {generator.skipped} skipped.")

    if args.check_files and not check_sound_files(sounds_dir, generator):
        return 1

    return 0


if __name__ == "__main__":
    exit(main())

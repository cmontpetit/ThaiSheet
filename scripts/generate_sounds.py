#!/usr/bin/env python3
"""
Generate Thai cheat sheet sound files using Google Text-to-Speech (gTTS).

Usage:
    python3 -m venv venv
    source venv/bin/activate
    pip install gTTS

    # Generate all sounds
    python3 generate_sounds.py --all

    # Generate specific types
    python3 generate_sounds.py --tone-marks
    python3 generate_sounds.py --tone-rules
    python3 generate_sounds.py --consonants
    python3 generate_sounds.py --vowels

Output files are saved to ThaiSheet/Resources/sounds/
"""

import argparse
import json
import os
from pathlib import Path

from gtts import gTTS


def get_project_paths():
    """Get project root and sounds directory paths."""
    script_dir = Path(__file__).parent.absolute()
    project_root = script_dir.parent
    sounds_dir = project_root / "ThaiSheet" / "Resources" / "sounds"
    cheatsheet_dir = project_root / "ThaiSheet" / "Resources" / "cheatsheet"
    return project_root, sounds_dir, cheatsheet_dir


def generate_sound(text: str, filepath: Path, description: str = "") -> None:
    """Generate a single sound file using gTTS."""
    desc = f" ({description})" if description else ""
    print(f"  Generating {filepath.name}{desc}...")
    tts = gTTS(text=text, lang='th')
    tts.save(str(filepath))


# =============================================================================
# TONE MARKS
# =============================================================================

def generate_tone_marks(sounds_dir: Path, cheatsheet_dir: Path) -> None:
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
            generate_sound(display, sounds_dir / filename, f"{on_low} tone (low class)")
            count += 1

        # Generate mid/high class sound (using ก)
        if on_mid_high != 'n/a':
            display = MID_CONSONANT + mark + "า"
            filename = f"cheat_sheet_tone_mark_{display}.mp3"
            generate_sound(display, sounds_dir / filename, f"{on_mid_high} tone (mid/high class)")
            count += 1

    print(f"  Generated {count} tone mark sounds")


# =============================================================================
# TONE RULES
# =============================================================================

def generate_tone_rules(sounds_dir: Path, cheatsheet_dir: Path) -> None:
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
                    generate_sound(word, sounds_dir / filename, f"{tone} tone")
                    count += 1

    print(f"  Generated {count} tone rule sounds")


# =============================================================================
# CONSONANTS
# =============================================================================

def generate_consonants(sounds_dir: Path, cheatsheet_dir: Path) -> None:
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
        generate_sound(name, sounds_dir / filename, name)
        count += 1

    print(f"  Generated {count} consonant sounds")


# =============================================================================
# VOWELS
# =============================================================================

def generate_vowels(sounds_dir: Path, cheatsheet_dir: Path) -> None:
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
                generate_sound(text, sounds_dir / filename)
                count += 1

    print(f"  Generated {count} vowel sounds")


# =============================================================================
# CLUSTERS
# =============================================================================

def generate_clusters(sounds_dir: Path, cheatsheet_dir: Path) -> None:
    """Generate cluster sound files using cluster + า."""
    print("\n[Clusters]")

    json_path = cheatsheet_dir / "clusters.json"
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    count = 0
    for cluster in data['clusters']:
        cluster_text = cluster['cluster']
        # Remove trailing dash and add า for pronunciation
        # e.g., "กร-" → "กรา"
        base = cluster_text.rstrip('-')
        display = base + "า"

        filename = f"cheat_sheet_cluster_{display}.mp3"
        sound_type = cluster.get('type', '')
        generate_sound(display, sounds_dir / filename, sound_type)
        count += 1

    print(f"  Generated {count} cluster sounds")


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Generate Thai cheat sheet sound files using gTTS'
    )
    parser.add_argument('--all', action='store_true', help='Generate all sounds')
    parser.add_argument('--tone-marks', action='store_true', help='Generate tone mark sounds')
    parser.add_argument('--tone-rules', action='store_true', help='Generate tone rule sample word sounds')
    parser.add_argument('--consonants', action='store_true', help='Generate consonant sounds')
    parser.add_argument('--vowels', action='store_true', help='Generate vowel sounds')
    parser.add_argument('--clusters', action='store_true', help='Generate cluster sounds')

    args = parser.parse_args()

    # Default to --all if no specific option provided
    if not any([args.all, args.tone_marks, args.tone_rules, args.consonants, args.vowels, args.clusters]):
        args.all = True

    project_root, sounds_dir, cheatsheet_dir = get_project_paths()

    if not sounds_dir.exists():
        print(f"Error: Sounds directory not found: {sounds_dir}")
        return 1

    print(f"Output directory: {sounds_dir}")

    if args.all or args.tone_marks:
        generate_tone_marks(sounds_dir, cheatsheet_dir)

    if args.all or args.tone_rules:
        generate_tone_rules(sounds_dir, cheatsheet_dir)

    if args.all or args.consonants:
        generate_consonants(sounds_dir, cheatsheet_dir)

    if args.all or args.vowels:
        generate_vowels(sounds_dir, cheatsheet_dir)

    if args.all or args.clusters:
        generate_clusters(sounds_dir, cheatsheet_dir)

    print("\nDone!")
    return 0


if __name__ == "__main__":
    exit(main())

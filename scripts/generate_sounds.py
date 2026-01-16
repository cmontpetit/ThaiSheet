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

# Tone marks with mid/high consonant (ก)
TONE_MARKS_MID_HIGH = [
    ("ก", "กา"),      # No mark - mid tone
    ("ก่", "ก่า"),    # Mai Ek - low tone
    ("ก้", "ก้า"),    # Mai Tho - falling tone
    ("ก๊", "ก๊า"),    # Mai Tri - high tone
    ("ก๋", "ก๋า"),    # Mai Chattawa - rising tone
]

# Tone marks with low consonant (ค)
TONE_MARKS_LOW = [
    ("ค", "คา"),      # No mark - mid tone
    ("ค่", "ค่า"),    # Mai Ek - falling tone
    ("ค้", "ค้า"),    # Mai Tho - high tone
]


def generate_tone_marks(sounds_dir: Path) -> None:
    """Generate tone mark sound files."""
    print("\n[Tone Marks]")

    print("Mid/High consonant (ก) series:")
    for mark, text in TONE_MARKS_MID_HIGH:
        filename = f"cheat_sheet_tone_mark_{mark}.mp3"
        generate_sound(text, sounds_dir / filename)

    print("Low consonant (ค) series:")
    for mark, text in TONE_MARKS_LOW:
        filename = f"cheat_sheet_tone_mark_{mark}.mp3"
        generate_sound(text, sounds_dir / filename)

    print(f"  Generated {len(TONE_MARKS_MID_HIGH) + len(TONE_MARKS_LOW)} tone mark sounds")


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
    for rule in data['toneRules']:
        if 'samples' in rule and rule['samples']:
            # Generate sound for the primary (first) sample
            sample = rule['samples'][0]
            word = sample['full']
            tone = rule['tone']
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

    args = parser.parse_args()

    # Default to --all if no specific option provided
    if not any([args.all, args.tone_marks, args.tone_rules, args.consonants, args.vowels]):
        args.all = True

    project_root, sounds_dir, cheatsheet_dir = get_project_paths()

    if not sounds_dir.exists():
        print(f"Error: Sounds directory not found: {sounds_dir}")
        return 1

    print(f"Output directory: {sounds_dir}")

    if args.all or args.tone_marks:
        generate_tone_marks(sounds_dir)

    if args.all or args.tone_rules:
        generate_tone_rules(sounds_dir, cheatsheet_dir)

    if args.all or args.consonants:
        generate_consonants(sounds_dir, cheatsheet_dir)

    if args.all or args.vowels:
        generate_vowels(sounds_dir, cheatsheet_dir)

    print("\nDone!")
    return 0


if __name__ == "__main__":
    exit(main())

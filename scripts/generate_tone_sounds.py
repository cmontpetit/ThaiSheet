#!/usr/bin/env python3
"""
Generate tone mark sound files using Google Text-to-Speech (gTTS).

Usage:
    python3 -m venv venv
    source venv/bin/activate
    pip install gTTS
    python3 generate_tone_sounds.py

Output files are saved to ThaiSheet/Resources/sounds/
"""

from gtts import gTTS
import os

# Output directory relative to project root
SOUNDS_DIR = "ThaiSheet/Resources/sounds"

# Tone marks with mid/high consonant (ก)
# Format: (display form, text to speak for gTTS)
TONE_MARKS_MID_HIGH = [
    ("ก", "กา"),      # No mark - mid tone
    ("ก่", "ก่า"),    # Mai Ek - falling tone
    ("ก้", "ก้า"),    # Mai Tho - low tone
    ("ก๊", "ก๊า"),    # Mai Tri - high tone
    ("ก๋", "ก๋า"),    # Mai Chattawa - rising tone
]

# Tone marks with low consonant (ค)
# Only 3 are valid (ค๊ and ค๋ are n/a for low consonants)
TONE_MARKS_LOW = [
    ("ค", "คา"),      # No mark - mid tone
    ("ค่", "ค่า"),    # Mai Ek - high tone
    ("ค้", "ค้า"),    # Mai Tho - falling tone
]


def generate_sound(mark: str, text: str, sounds_dir: str) -> None:
    """Generate a single tone mark sound file."""
    filename = f"cheat_sheet_tone_mark_{mark}.mp3"
    filepath = os.path.join(sounds_dir, filename)
    print(f"Generating {filename}...")
    tts = gTTS(text=text, lang='th')
    tts.save(filepath)
    print(f"  Saved to {filepath}")


def main():
    # Find project root (where this script's parent 'scripts' folder is)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    sounds_dir = os.path.join(project_root, SOUNDS_DIR)

    if not os.path.exists(sounds_dir):
        print(f"Error: Sounds directory not found: {sounds_dir}")
        return

    print(f"Output directory: {sounds_dir}\n")

    print("Generating mid/high consonant (ก) tone marks...")
    for mark, text in TONE_MARKS_MID_HIGH:
        generate_sound(mark, text, sounds_dir)

    print("\nGenerating low consonant (ค) tone marks...")
    for mark, text in TONE_MARKS_LOW:
        generate_sound(mark, text, sounds_dir)

    print("\nDone! Generated 8 tone mark sound files.")


if __name__ == "__main__":
    main()

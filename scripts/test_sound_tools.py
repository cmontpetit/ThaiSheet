import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace

from generate_sound_catalog import build_catalog, rendered_catalog
from generate_sounds import (
    AudioQuality,
    SoundGenerator,
    canonical_recording_item,
    inconsistent_identical_inputs,
    items_by_synthesis_text,
    unify_identical_inputs,
)
from sound_inventory import SoundItem, load_sound_inventory


PROJECT_ROOT = Path(__file__).resolve().parent.parent
CHEATSHEET_DIR = PROJECT_ROOT / "ThaiSheet" / "Resources" / "cheatsheet"
SOUNDS_DIR = PROJECT_ROOT / "ThaiSheet" / "Resources" / "sounds"
METADATA_PATH = PROJECT_ROOT / "scripts" / "recorded_audio_metadata.json"


class SoundInventoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.items = load_sound_inventory(CHEATSHEET_DIR)
        cls.by_id = {item.id: item for item in cls.items}

    def test_inventory_matches_bundled_files(self):
        self.assertEqual(len(self.items), 391)
        expected = {item.filename for item in self.items}
        existing = {path.name for path in SOUNDS_DIR.glob("*.mp3")}
        self.assertEqual(expected, existing)

    def test_synthesis_rules_are_preserved(self):
        self.assertEqual(self.by_id["consonant:ก"].synthesis_text, "กอ ไก่")
        self.assertEqual(self.by_id["vowel:กึ"].synthesis_text, "กึ")
        self.assertEqual(self.by_id["vowel:กึ-"].synthesis_text, "กึ")
        self.assertEqual(self.by_id["cluster:-ทร"].synthesis_text, "-ทร")

    def test_excluded_ri_vowel_has_no_audio(self):
        self.assertNotIn("vowel:ฤ-", self.by_id)
        self.assertFalse((SOUNDS_DIR / "cheat_sheet_vowel_ฤ-.mp3").exists())

    def test_sample_word_metadata_is_available(self):
        teacher = self.by_id["sample-word:ครู"]
        self.assertEqual(teacher.romanization, "khruu")
        self.assertEqual(teacher.meaning_en, "teacher")
        self.assertEqual(teacher.meaning_fr, "professeur")

    def test_identical_synthesis_inputs_share_one_recording(self):
        self.assertEqual(inconsistent_identical_inputs(SOUNDS_DIR, self.items), [])

    def test_canonical_recording_prefers_reviewed_or_open_entries(self):
        grouped = items_by_synthesis_text(self.items)
        self.assertEqual(canonical_recording_item(grouped["กา"]).id, "sample-word:กา")
        self.assertEqual(canonical_recording_item(grouped["เกีย"]).id, "vowel:เกีย")
        self.assertEqual(canonical_recording_item(grouped["หนา"]).id, "tone-rule:หนา")


class AudioQualityTests(unittest.TestCase):
    def test_rejects_short_quiet_audio(self):
        quality = AudioQuality(duration_seconds=0.264, max_volume_db=-35.7)
        self.assertEqual(len(quality.issues(0.35, -24.0)), 2)

    def test_accepts_audible_audio(self):
        quality = AudioQuality(duration_seconds=0.72, max_volume_db=-8.0)
        self.assertEqual(quality.issues(0.35, -24.0), [])


class IdenticalInputReuseTests(unittest.TestCase):
    def test_generator_synthesizes_identical_input_once(self):
        generator = SoundGenerator(
            language_code="th-TH",
            voice_name="test",
            speaking_rate=1.0,
            pitch=0.0,
            volume_gain_db=0.0,
            force=True,
            dry_run=True,
            retries=0,
            retry_delay=0.0,
            quality_check=False,
        )
        generator.dry_run = False
        generator.texttospeech = object()
        generator.client = object()
        generator.voice = object()
        generator.audio_config = object()
        generator.google_exceptions = object()
        synthesis_calls = []
        generator.synthesize = lambda text: synthesis_calls.append(text) or SimpleNamespace(audio_content=b"raw")
        generator.write_processed_audio = lambda source, filepath: filepath.write_bytes(b"processed")

        with TemporaryDirectory() as temp_dir, redirect_stdout(StringIO()):
            first = Path(temp_dir) / "first.mp3"
            second = Path(temp_dir) / "second.mp3"
            generator.generate("เกีย", first)
            generator.generate("เกีย", second)

            self.assertEqual(synthesis_calls, ["เกีย"])
            self.assertEqual(first.read_bytes(), second.read_bytes())

    def test_unify_identical_inputs_copies_the_canonical_take(self):
        items = [
            SoundItem("tone-rule:กา", "tone_rule", "กา", "กา", "กา", "tone.mp3"),
            SoundItem("vowel:กา", "vowel", "กา", "กา", "กา", "vowel.mp3"),
            SoundItem("sample-word:กา", "sample_word", "กา", "กา", "กา", "sample.mp3"),
        ]
        with TemporaryDirectory() as temp_dir:
            sounds_dir = Path(temp_dir)
            (sounds_dir / "tone.mp3").write_bytes(b"tone")
            (sounds_dir / "vowel.mp3").write_bytes(b"vowel")
            (sounds_dir / "sample.mp3").write_bytes(b"sample")

            with redirect_stdout(StringIO()):
                changed_groups, changed_files = unify_identical_inputs(sounds_dir, items)

            self.assertEqual(changed_groups, 1)
            self.assertEqual(changed_files, 2)
            self.assertTrue(all((sounds_dir / item.filename).read_bytes() == b"sample" for item in items))


class SoundCatalogTests(unittest.TestCase):
    def test_catalog_contains_hashes_and_metadata(self):
        catalog = build_catalog(SOUNDS_DIR, METADATA_PATH)
        self.assertEqual(len(catalog["items"]), 391)
        self.assertEqual(catalog["audio"]["voice"], "th-TH-Chirp3-HD-Kore")
        self.assertTrue(all(len(item["sha256"]) == 64 for item in catalog["items"]))
        self.assertIn("window.THAISHEET_SOUND_CATALOG", rendered_catalog(catalog))


if __name__ == "__main__":
    unittest.main()

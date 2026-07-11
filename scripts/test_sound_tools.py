import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from types import SimpleNamespace
from tempfile import TemporaryDirectory

from generate_sound_catalog import build_catalog, rendered_catalog
from generate_sounds import AudioQuality, SoundGenerator
from sound_inventory import load_sound_inventory


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


class AudioQualityTests(unittest.TestCase):
    def test_rejects_short_quiet_audio(self):
        quality = AudioQuality(duration_seconds=0.264, max_volume_db=-35.7)
        self.assertEqual(len(quality.issues(0.35, -24.0)), 2)

    def test_accepts_audible_audio(self):
        quality = AudioQuality(duration_seconds=0.72, max_volume_db=-8.0)
        self.assertEqual(quality.issues(0.35, -24.0), [])


class SoundGeneratorTests(unittest.TestCase):
    def test_identical_inputs_reuse_processed_audio(self):
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

        def synthesize(text):
            synthesis_calls.append(text)
            return SimpleNamespace(audio_content=b"synthesized audio")

        generator.synthesize = synthesize
        generator.write_processed_audio = lambda source, destination: destination.write_bytes(
            b"processed:" + source.read_bytes()
        )

        with TemporaryDirectory() as temp_dir, redirect_stdout(StringIO()):
            first = Path(temp_dir) / "first.mp3"
            second = Path(temp_dir) / "second.mp3"
            generator.generate("same Thai input", first)
            generator.generate("same Thai input", second)

            self.assertEqual(synthesis_calls, ["same Thai input"])
            self.assertEqual(first.read_bytes(), second.read_bytes())


class SoundCatalogTests(unittest.TestCase):
    def test_catalog_contains_hashes_and_metadata(self):
        catalog = build_catalog(SOUNDS_DIR, METADATA_PATH)
        self.assertEqual(len(catalog["items"]), 391)
        self.assertEqual(catalog["audio"]["voice"], "th-TH-Neural2-C")
        self.assertTrue(all(len(item["sha256"]) == 64 for item in catalog["items"]))
        self.assertIn("window.THAISHEET_SOUND_CATALOG", rendered_catalog(catalog))

    def test_local_catalog_plays_working_tree_audio(self):
        html = (PROJECT_ROOT / "docs" / "sounds.html").read_text()
        self.assertIn('window.location.protocol === "file:"', html)
        self.assertIn('["localhost", "127.0.0.1", "::1"]', html)
        self.assertIn('"../ThaiSheet/Resources/sounds/"', html)


if __name__ == "__main__":
    unittest.main()

import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from types import SimpleNamespace
from tempfile import TemporaryDirectory

from generate_sound_catalog import build_catalog, rendered_catalog
from generate_sound_review import current_voice_label
from generate_sounds import AudioQuality, SoundGenerator
from generate_vowel_pronunciation_review import (
    internal_silence_intervals,
    load_candidates,
    render_review,
)
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
        self.assertEqual(len(self.items), 388)
        expected = {item.filename for item in self.items}
        existing = {path.name for path in SOUNDS_DIR.glob("*.mp3")}
        self.assertEqual(expected, existing)

    def test_synthesis_rules_are_preserved(self):
        self.assertEqual(self.by_id["consonant:ก"].synthesis_text, "กอ ไก่")
        self.assertEqual(self.by_id["vowel:กึ:short_open"].synthesis_text, "หึ")
        self.assertEqual(self.by_id["vowel:กึ-:short_closed"].synthesis_text, "ดึก")
        self.assertEqual(self.by_id["cluster:-ทร"].synthesis_text, "-ทร")

    def test_ri_vowel_uses_unambiguous_real_word(self):
        ri = self.by_id["vowel:ฤ-:short_closed"]
        self.assertEqual(ri.synthesis_text, "ฤทธิ์")
        self.assertEqual(ri.filename, "cheat_sheet_vowel_ฤทธิ์.mp3")

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
        self.assertEqual(len(catalog["items"]), 388)
        self.assertIn("th-TH-Chirp3-HD-Kore", catalog["audio"]["voice"])
        self.assertTrue(all(len(item["sha256"]) == 64 for item in catalog["items"]))
        self.assertIn("window.THAISHEET_SOUND_CATALOG", rendered_catalog(catalog))

    def test_local_catalog_plays_working_tree_audio(self):
        html = (PROJECT_ROOT / "docs" / "sounds.html").read_text()
        self.assertIn('window.location.protocol === "file:"', html)
        self.assertIn('["localhost", "127.0.0.1", "::1"]', html)
        self.assertIn('"../ThaiSheet/Resources/sounds/"', html)


class SoundReviewTests(unittest.TestCase):
    def test_current_voice_comes_from_recorded_audio_metadata(self):
        label = current_voice_label()
        self.assertIn("th-TH-Neural2-C", label)
        self.assertIn("th-TH-Chirp3-HD-Kore", label)


class VowelPronunciationReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.candidates = load_candidates()

    def test_includes_every_displayed_vowel_variant(self):
        self.assertEqual(len(self.candidates), 73)

    def test_duplicate_spelling_keeps_distinct_pronunciation_words(self):
        closed_er = [
            item for item in self.candidates
            if item["form"] == "เกิ-" and item["ending"] == "Closed"
        ]
        self.assertEqual([item["word"] for item in closed_er], ["เงิน", "เดิน"])

    def test_ri_reading_uses_real_word(self):
        ri = next(item for item in self.candidates if item["form"] == "ฤ-")
        self.assertEqual(ri["word"], "ฤทธิ์")
        self.assertEqual(ri["romanization"], "rít")

    def test_missing_candidates_are_explicit(self):
        missing_forms = {item["form"] for item in self.candidates if not item["word"]}
        self.assertEqual(missing_forms, {"เกือะ", "ก็อย", "แก็ว", "เกอว", "ฦ"})

    def test_review_page_embeds_candidate_data(self):
        page = render_review({
            "candidateVoice": "test-voice",
            "currentVoice": "current",
            "items": self.candidates[:1],
            "counts": {
                "variants": 1,
                "mapped": 1,
                "missingWords": 0,
                "missingAudio": 0,
                "duplicateSpellings": 0,
                "automaticAudioFlags": 0,
            },
        })
        self.assertIn("Vowel pronunciation-word review", page)
        self.assertIn("test-voice", page)
        self.assertIn("Export review", page)
        self.assertIn('JSON.stringify(payload, null, 2) + "\\n"', page)

    def test_internal_silence_detection_ignores_clip_padding(self):
        log = "\n".join([
            "silence_start: 0",
            "silence_end: 0.52 | silence_duration: 0.52",
            "silence_start: 1.18",
            "silence_end: 1.49 | silence_duration: 0.31",
            "silence_start: 2.99",
            "silence_end: 3.26 | silence_duration: 0.27",
        ])
        self.assertEqual(internal_silence_intervals(log, 3.26), [(1.18, 1.49)])


if __name__ == "__main__":
    unittest.main()

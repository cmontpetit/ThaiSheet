# ThaiSheet

An open-source iOS quick reference to help you learn to read Thai, based on a comprehensive cheatsheet.

**Latest release: 1.1.** App Store release details are tracked in [APP_STORE_METADATA.md](APP_STORE_METADATA.md).

## Screenshots

| Vowels | Reading practice | Consonant details |
|---|---|---|
| ![Vowel reference](docs/screenshots/appstore-1.1/iphone/01-vowels.jpg) | ![Vowel practice with hidden transcriptions](docs/screenshots/appstore-1.1/iphone/02-vowels-practice.jpg) | ![Consonant details](docs/screenshots/appstore-1.1/iphone/03-consonant-details.jpg) |

| Tones | Completed flashcard | Progress |
|---|---|---|
| ![Tone marks and rules](docs/screenshots/appstore-1.1/iphone/04-tones.jpg) | ![Completed flashcard](docs/screenshots/appstore-1.1/iphone/05-flashcard-completed.jpg) | ![SRS learning progress](docs/screenshots/appstore-1.1/iphone/06-progress.jpg) |

The latest iPhone screenshots are also shown on the [website](https://cmontpetit.github.io/ThaiSheet/). App Store-sized iPhone and iPad sets are kept in [docs/screenshots/appstore-1.1/](docs/screenshots/appstore-1.1/).

## Features

- **Reference Browser** - Browse consonants, vowels, tone rules, tone marks, and clusters with search and filtering
- **Multiple Pronunciation Voices** - Choose ElevenLabs Matilda (default), Google Neural2-C, Google Chirp3-HD Kore, or an installed Thai system voice
- **Per-Item Voice Overrides** - Keep one default voice while assigning a different voice to individual reference entries
- **Reading Practice** - Hide reference transcriptions until you reveal them
- **Complementary Flashcards** - Practice what you look up with multiple-choice questions, using a Wanikani-style spaced repetition system with 8 progression stages
- **Smart Card Selection** - Choose between intelligent SRS-based ordering or sequential study
- **Customizable Filters** - Focus on specific consonant classes, vowel types, or tone rules
- **Progress Tracking** - Detailed statistics showing mastery levels across all card types
- **Optional iCloud Sync** - Sync learning progress and settings across devices when enabled
- **Localized** - Available in English and French, with easy community translation support
- **Accessible** - VoiceOver labels and hints across playable reference items

## Requirements

- iOS 17.0+
- Xcode 16+

## Build & Run

```bash
# Build for simulator
xcodebuild -project ThaiSheet.xcodeproj -scheme ThaiSheet \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run tests
xcodebuild -project ThaiSheet.xcodeproj -scheme ThaiSheet \
  -destination 'platform=iOS Simulator,name=iPhone 17' test

# Verify an App Store release build has no coverage instrumentation
scripts/check_release_binary.sh /path/to/ThaiSheet.app
```

## Sound Generation

ThaiSheet bundles three complete, explicitly suffixed recording sets:

- `matilda` — ElevenLabs Matilda using `eleven_v3` (the app default)
- `neural2` — Google Cloud Text-to-Speech `th-TH-Neural2-C`
- `kore` — Google Cloud Text-to-Speech `th-TH-Chirp3-HD-Kore`

Installed Apple Thai voices are synthesized live on-device and are never bundled. For Google voice generation, first-time setup is:

```bash
cd scripts && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
gcloud auth application-default login
```

After setup, activate the virtual environment and run:

```bash
source scripts/venv/bin/activate
python3 scripts/generate_sounds.py --all --dry-run --check-files
python3 scripts/generate_sounds.py --all --force --normalize-lufs -18 --check-files
# Or specific types: --consonants, --vowels, --tone-marks, --tone-rules
```

Google production files use the `_neural2` or `_kore` suffix. Matilda files are
generated with `scripts/generate_elevenlabs_sounds.py` and use `_matilda`.
All three complete sets are normalized to -18 LUFS with a -1.5 dB true-peak
limit. Use an explicit `--voice-name` when producing a Google candidate, or a
scratchpad output directory when producing an ElevenLabs candidate.
Generated responses are rejected and retried when they are too short or nearly
silent. Loudness normalization includes a true-peak limit to avoid clipping.
Within one generation run, exact duplicate synthesis inputs reuse the first
processed response so their MP3 files are byte-identical.
Candidate sets can be written safely below `scratchpad/` with `--output-dir` and
compared with the bundled set using `scripts/generate_sound_review.py`.

To review the real-word vowel pronunciation mapping, build the dedicated
73-variant page. It uses the existing
per-form sample words as initial candidates and compares their candidate voice
recordings with the bundled vowel-word recordings:

```bash
python3 scripts/generate_vowel_pronunciation_review.py \
  --candidate-dir scratchpad/kore-candidate
```

Review decisions are stored locally in the browser and can be exported as JSON.
Forms without a defensible real-word candidate remain explicitly unvoiced.
The page also flags unusually long or internally segmented one-word responses,
which can indicate that a generative TTS voice added or repeated speech.

The public [pronunciation catalog](https://cmontpetit.github.io/ThaiSheet/sounds.html)
is generated from the same canonical inventory and lets reviewers switch among
all three bundled voices. After changing JSON data, audio, or recorded-voice
metadata, update and verify it with:

```bash
python3 scripts/generate_sound_catalog.py
python3 scripts/generate_sound_catalog.py --check
```

When previewing `docs/sounds.html` locally, serve the repository root (rather
than only `docs/`) so the catalog can play audio from the working tree.

## Data & Audio Provenance

The bundled learning data (`ThaiSheet/Resources/cheatsheet/*.json`) is an independent
compilation of factual information about the Thai script — character inventory,
consonant classes, sounds, tone rules — expressed in this project's own structure and
wording, with corrections and additions by the author. No third-party images, prose,
or artwork are included.

Bundled pronunciation audio was generated with
[Google Cloud Text-to-Speech](https://cloud.google.com/text-to-speech) and
ElevenLabs (see Sound Generation above).

## Contributing

See [CONTRIBUTING.md](.github/CONTRIBUTING.md) for guidelines on how to contribute, including how to add translations for new languages.

## Privacy

ThaiSheet does not include analytics, ads, tracking, or third-party SDKs. Learning progress and settings are stored locally with UserDefaults. If iCloud Sync is enabled, the app syncs learning progress and settings through Apple's iCloud key-value store.

See [PRIVACY.md](PRIVACY.md) for the full privacy policy.

## Support

Use [GitHub Issues](https://github.com/cmontpetit/ThaiSheet/issues) for bug reports and feature requests. See [SUPPORT.md](SUPPORT.md) for details.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

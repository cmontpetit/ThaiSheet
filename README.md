# ThaiSheet

An open-source iOS app for learning to read Thai, based on a comprehensive cheatsheet.

App Store release preparation is tracked in [APP_STORE_METADATA.md](APP_STORE_METADATA.md).

## Screenshots

Screenshots will be added before the first App Store release.

## Features

- **Flashcards with SRS** - Multiple-choice questions about Thai characters using a Wanikani-style spaced repetition system with 8 progression stages
- **Reference Browser** - Browse consonants, vowels, tone rules, tone marks, and clusters with search and filtering
- **Audio Playback** - Hear pronunciation for characters and syllables
- **Smart Card Selection** - Choose between intelligent SRS-based ordering or sequential study
- **Progress Tracking** - Detailed statistics showing mastery levels across all card types
- **Optional iCloud Sync** - Sync learning progress and settings across devices when enabled
- **Customizable Filters** - Focus on specific consonant classes, vowel types, or tone rules
- **Localized** - Available in English and French, with easy community translation support

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

Sound files are generated with [Google Cloud Text-to-Speech](https://cloud.google.com/text-to-speech). First-time setup:

```bash
cd scripts && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
gcloud auth application-default login
```

After setup, activate the virtual environment and run:

```bash
source scripts/venv/bin/activate
python3 scripts/generate_sounds.py --all --dry-run --check-files
python3 scripts/generate_sounds.py --all --force --check-files
# Or specific types: --consonants, --vowels, --tone-marks, --tone-rules
```

The default Thai voice is `th-TH-Neural2-C`. Use `--voice-name th-TH-Standard-A` or another supported Thai voice to compare output before committing regenerated MP3s.

## Contributing

See [CONTRIBUTING.md](.github/CONTRIBUTING.md) for guidelines on how to contribute, including how to add translations for new languages.

## Privacy

ThaiSheet does not include analytics, ads, tracking, or third-party SDKs. Learning progress and settings are stored locally with UserDefaults. If iCloud Sync is enabled, the app syncs learning progress and settings through Apple's iCloud key-value store.

See [PRIVACY.md](PRIVACY.md) for the full privacy policy draft.

## Support

Use [GitHub Issues](https://github.com/cmontpetit/ThaiSheet/issues) for bug reports and feature requests once the repository is public. See [SUPPORT.md](SUPPORT.md) for details.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

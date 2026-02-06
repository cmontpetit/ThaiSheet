# ThaiSheet

An open-source iOS app for learning to read Thai, based on a comprehensive cheatsheet.

<!-- TODO: Add App Store badge once published -->

## Screenshots

<!-- TODO: Add screenshots of flashcard view, reference browser, and SRS stats -->

## Features

- **Flashcards with SRS** — Multiple-choice questions about Thai characters using a Wanikani-style spaced repetition system with 8 progression stages
- **Reference Browser** — Browse consonants, vowels, tone rules, tone marks, and clusters with search and filtering
- **Audio Playback** — Hear native pronunciation for all characters and syllables
- **Smart Card Selection** — Choose between intelligent SRS-based ordering or sequential study
- **Progress Tracking** — Detailed statistics showing mastery levels across all card types
- **Customizable Filters** — Focus on specific consonant classes, vowel types, or tone rules
- **Localized** — Available in English and French, with easy community translation support

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
```

## Sound Generation

Sound files are generated using Google Cloud Text-to-Speech. First-time setup:

```bash
cd scripts && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
```

After setup, activate the virtual environment and run:

```bash
source scripts/venv/bin/activate && python3 scripts/generate_sounds.py --all
# Or specific types: --consonants, --vowels, --tone-marks, --tone-rules
```

## Contributing

See [CONTRIBUTING.md](.github/CONTRIBUTING.md) for guidelines on how to contribute, including how to add translations for new languages.

## Privacy

This app does not collect, store, or transmit any personal data. All learning progress is stored locally on your device using UserDefaults.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

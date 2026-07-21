# Contributing to ThaiSheet

Thank you for your interest in contributing to ThaiSheet! This guide will help you get started.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Open `ThaiSheet.xcodeproj` in Xcode 16+
4. Build and run on the iOS Simulator (iPhone 17 recommended)

## Development Setup

### Sound Files

ThaiSheet bundles complete Neural2, Kore, and Matilda recording sets. The two
Google sets are generated with Google Cloud Text-to-Speech; Matilda is generated
with ElevenLabs `eleven_v3`. First-time Google setup (from the repository root):

```bash
cd scripts && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt && cd ..
gcloud auth application-default login
```

Then, to regenerate sounds (from the repository root):

```bash
source scripts/venv/bin/activate
python3 scripts/generate_sounds.py --all --dry-run --check-files
python3 scripts/generate_sounds.py --all --force --normalize-lufs -18 --check-files
python3 scripts/generate_sound_catalog.py
python3 scripts/generate_sound_catalog.py --check
```

The sound catalog contains a hash for all three versions of every recording, so
it must be regenerated when any bundled audio changes even if filenames stay the same. Update
`scripts/recorded_audio_metadata.json` when the provider, voice, or processing
method changes.

### Running Tests

```bash
xcodebuild -project ThaiSheet.xcodeproj -scheme ThaiSheet \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Code Style

- Use Swift conventions (camelCase for properties/methods, PascalCase for types)
- Use `@Observable` with `didSet` for UserDefaults persistence (not Combine)
- Use protocol + environment injection for dependencies (not singletons)
- Keep views focused — extract reusable components to `FlashcardComponents.swift`
- Use `BundleLoader` for all JSON data loading

## Pull Request Guidelines

1. Create a feature branch from `main`
2. Keep PRs focused on a single change
3. Include tests for new business logic
4. Ensure all existing tests pass
5. Update documentation if needed

## Adding a New Language

ThaiSheet uses String Catalogs (`.xcstrings`) for localization. To add a new language:

1. Open `ThaiSheet.xcodeproj` in Xcode
2. Select `Localizable.xcstrings` in the project navigator
3. Click the `+` button at the bottom of the language list to add your language
4. Translate all strings in the String Catalog editor
5. Add your language option to the `supportedLanguages` array in `FlashcardSettings.swift`
6. Test by switching to your language in the app's Settings > Language (the picker is available in DEBUG builds only; release builds follow the system language)
7. Submit a PR with your translations

**Important:** Do not translate Thai characters, sound file names, UserDefaults keys, or JSON data identifiers.

## Reporting Issues

- Use the [Bug Report](ISSUE_TEMPLATE/bug_report.md) template for bugs
- Use the [Feature Request](ISSUE_TEMPLATE/feature_request.md) template for ideas
- Search existing issues before creating a new one

## Architecture

See [ARCHITECTURE.md](../ARCHITECTURE.md) for an overview of the codebase structure and patterns.

# Contributing to ThaiSheet

Thank you for your interest in contributing to ThaiSheet! This guide will help you get started.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Open `ThaiSheet.xcodeproj` in Xcode 16+
4. Build and run on the iOS Simulator (iPhone 17 recommended)

## Development Setup

### Sound Files

Sound files are generated using Google Cloud Text-to-Speech:

```bash
cd scripts && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
source scripts/venv/bin/activate && python3 scripts/generate_sounds.py --all
```

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
6. Test by switching to your language in the app's Settings > Language
7. Submit a PR with your translations

**Important:** Do not translate Thai characters, sound file names, UserDefaults keys, or JSON data identifiers.

## Reporting Issues

- Use the [Bug Report](.github/ISSUE_TEMPLATE/bug_report.md) template for bugs
- Use the [Feature Request](.github/ISSUE_TEMPLATE/feature_request.md) template for ideas
- Search existing issues before creating a new one

## Architecture

See [ARCHITECTURE.md](../ARCHITECTURE.md) for an overview of the codebase structure and patterns.

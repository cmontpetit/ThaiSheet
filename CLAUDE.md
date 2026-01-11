# Aksorn

## About Aksorn

iOS application for learning to read Thai, based on a comprehensive cheatsheet.

**Target users:** Thai language learners (beginner to intermediate)

**Key features:**
- **Flashcard tab**: Cards showing Thai characters with multiple-choice questions about their characteristics. Includes spaced repetition scoring (Anki-style) to optimize learning frequency.
- **Reference tab**: Browse cheatsheet clips with search by character characteristics.

**Platforms:** iPhone, iPad

**Note:** On-device LLM (Foundation Models) - TBD if needed.

## Project Resources

- **Source cheatsheet images:** `external-resources/` (project root)
- **Generated data:** `Aksorn/Resources/` (bundled with app)
- **App assets:** `Aksorn/Assets.xcassets`


## Apple Framework Documentation

Reference documentation for iOS 26 / WWDC 2025 features is available at:
```
/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/
```

Key docs for this project:
- `FoundationModels-Using-on-device-LLM-in-your-app.md` - On-device LLM API
- `SwiftUI-Implementing-Liquid-Glass-Design.md` - Liquid Glass design patterns
- `UIKit-Implementing-Liquid-Glass-Design.md` - UIKit glass design

Other useful docs in that folder:
- `AppIntents-Updates.md`
- `Swift-Concurrency-Updates.md`
- `SwiftData-Class-Inheritance.md`
- `SwiftUI-WebKit-Integration.md`
- `SwiftUI-Styled-Text-Editing.md`

## Build & Run

```bash
# Build
xcodebuild -project Aksorn.xcodeproj -scheme Aksorn -configuration Debug build

# Run tests
xcodebuild -project Aksorn.xcodeproj -scheme Aksorn test
```

## Project Conventions

<!-- Add your coding style, architecture patterns, and conventions here -->

### Interpreting the cheatsheet and clip files
- The cheatsheet is interpreted and stored as a data model in the app using UTF characters, with all of their characteristics.
- The clip-* files are just subsets of the cheatsheet-complete png file, for easier processing.
- The consonants "initial" and "final" columns are the sounds that they would sound like in English.
- The vowels "sound" column has the same purpose as the consonants initial and final columns.
- In the model, these two columns should be marked as Englis, since a French version, for instance, may have different letters.
- The place holder "◌" in the clip-vowel file will be replaced with the character "ก"


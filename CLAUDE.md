# ThaiSheet

**Project location:** `/Users/claude/dev/claude-code/ios/ThaiSheet` (renamed from Aksorn)

## About ThaiSheet

iOS application for learning to read Thai, based on a comprehensive cheatsheet.

**Target users:** Thai language learners (beginner to intermediate)

**Key features:**
- **Flashcard tab**: Cards showing Thai characters with multiple-choice questions about their characteristics. Uses Wanikani-style SRS (spaced repetition) to optimize learning.
- **Reference tab**: Browse cheatsheet clips with search by character characteristics.

**Platforms:** iPhone, iPad

**Note:** On-device LLM (Foundation Models) - TBD if needed.

## Project Resources

- **Source cheatsheet images:** `external-resources/` (project root)
- **Generated data:** `ThaiSheet/Resources/` (bundled with app)
- **App assets:** `ThaiSheet/Assets.xcassets`


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
# Build for simulator (use iPhone 17 - available on this system)
xcodebuild -project ThaiSheet.xcodeproj -scheme ThaiSheet -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run tests
xcodebuild -project ThaiSheet.xcodeproj -scheme ThaiSheet test
```

## Project Conventions

### Architecture
- See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation

### @Observable and UserDefaults
- `FlashcardSettings` uses `@Observable` with stored properties and `didSet` for persistence
- `FlashcardSettings` accepts `UserDefaults` as init param (default `.standard`) for testability
- **Important:** Computed properties bypass `@Observable` tracking - always use stored properties
- Pattern: `var setting: Bool { didSet { defaults.set(setting, forKey: "key") } }`
- Initialize from UserDefaults in `init()`, not via computed getters

### Interpreting the cheatsheet and clip files
- The cheatsheet is interpreted and stored as a data model in the app using UTF characters, with all of their characteristics.
- The clip-* files are just subsets of the cheatsheet-complete png file, for easier processing.
- The consonants "initial" and "final" columns are the sounds that they would sound like in English.
- The vowels "sound" column has the same purpose as the consonants initial and final columns.
- In the model, these two columns should be marked as English, since a French version, for instance, may have different letters.
- The placeholder "◌" (U+25CC dotted circle) is replaced with "ก" in JSON data.

### Data deviations from the source cheatsheet (audited July 2026)
The app's data intentionally differs from `external-resources/complete-cheatsheet.png` where the PNG is wrong:
- ซ final sound: PNG says "-s" → app uses "-t" (Thai has no final /s/)
- ย/ว finals: PNG "[vowel]" → app "-y"/"-w"
- Added หญ- to silent ห combinations (missing from PNG; หญิง/ใหญ่/หญ้า)
- Added ฦ/ฦๅ (obsolete letters, not in PNG) and the no-mark tone row (Mid/Mid)
- ช้าง transcription: PNG "chang" → "chaang" (long vowel)
- The PNG's 7-row tone rule table is CORRECT — do not add rules (a bogus "High+Long+Dead→Falling" was once introduced and removed; high-class dead syllables are always Low tone)
- Cluster romanization follows the consonant scheme (g-/dt-/bp-): กร- = gr-, ตร- = dtr-, ปร- = bpr-

### Vowel notation
- **Closed** = syllable ends with consonant → form includes `-` to show where final consonant goes
- **Open** = syllable ends with vowel sound → no dash needed
- Example: short closed `กั-` (needs final consonant), short open `กะ` (vowel terminates)

### Thai character rendering on iOS
- The dotted circle `◌` (U+25CC) causes double-circle rendering on iOS when combined with vowel marks that go above/below (e.g., `◌ิ` shows two circles) — in every font tested (system, Thonburi, SukhumvitSet)
- For data, use `ก` as the consonant placeholder; for display, `ThaiDisplay.placeholder` (Models/ThaiDisplay.swift) converts it:
  - ก before an above/below combining mark → hair space (U+200A): the shaper auto-inserts a single dotted circle under the orphaned mark
  - ก elsewhere → explicit `◌` (U+25CC)
  - Zero-width characters (ZWSP/ZWJ) do NOT work as the mark's stand-in base — the Thai shaper deletes them and glues the mark onto the preceding letter (e.g. onto preposed เ/แ/โ)
- Swift gotcha: `replacingOccurrences(of: "ก")` will not match ก followed by a combining mark (grapheme-cluster search); replace at the `unicodeScalars` level instead

### Project Structure
- `ThaiSheet/Models/` - Data models (Consonant, Vowel, ToneRule, ToneMark, Cluster, VowelCard, ToneMarkCard, ToneRuleCard), FlashcardItem, FlashcardSettings, LearningModel, CardProgress, ThaiColors
- `ThaiSheet/Views/` - SwiftUI views (CheatsheetBrowserView, flashcard views, row views, FlashcardComponents, SRSStatsView, FilterView, SettingsView)
- `ThaiSheet/Services/` - AudioPlayer (protocol + environment injection), BundleLoader, CardSelectionStrategy (Sequential/Wanikani), FlashcardManager
- `ThaiSheet/Resources/` - JSON data files and sounds

### Sound Files
- Location: `ThaiSheet/Resources/sounds/`
- Naming: `cheat_sheet_{type}_{key}.mp3` (e.g., `cheat_sheet_consonant_ก.mp3`, `cheat_sheet_vowel_กา.mp3`)
- Types: `consonant`, `vowel`, `tone_mark`, `tone_rule`, `cluster`
- Audio injection: `AudioPlaying` protocol via `@Environment(\.audioPlayer)` — never use `AudioPlayer.shared` directly in views

### Sound File Generation
- Script: `scripts/generate_sounds.py` (uses Google Text-to-Speech)
- First-time setup:
  ```bash
  cd scripts && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
  ```
- After setup, just activate and run:
  ```bash
  source scripts/venv/bin/activate && python3 scripts/generate_sounds.py --all
  # Or specific types: --consonants, --vowels, --tone-marks, --tone-rules
  ```
- Tone mark sounds: 8 files using fixed consonants (ค for low class, ก for mid/high class) + า vowel

### Flashcard Design Decisions
- **Tone Marks**: Use fixed consonants matching the reference (ค for low, ก for mid/high)
  - 8 total cards: 3 low class (คา, ค่า, ค้า) + 5 mid/high class (กา, ก่า, ก้า, ก๊า, ก๋า)
  - Display shows full syllable with า vowel for proper pronunciation
- **Tone Rules**: Use predefined sample words (not random combinations) because:
  - Real vocabulary is more pedagogically useful
  - Combinatorial explosion would require thousands of sound files
  - `full` = complete word, `focus` = syllable demonstrating the rule

### SRS System (Wanikani-style)
The app uses a Wanikani-inspired spaced repetition system with 8 stages:

| Stage | Name | Interval |
|-------|------|----------|
| 1 | Learning | 4 hours |
| 2 | Learning | 8 hours |
| 3 | Apprentice | 1 day |
| 4 | Apprentice | 2 days |
| 5 | Familiar | 1 week |
| 6 | Familiar | 2 weeks |
| 7 | Confident | 1 month |
| 8 | Mastered | Never shown again |

**Progression rules:**
- Correct answer: advance 1 stage
- Incorrect answer: drop 2 stages (minimum Apprentice 1)
- Stage 0 (New) = never reviewed

**Capped advancement:**
- When filters make questions trivial (e.g., only one consonant class enabled), advancement is capped at Familiar 2 (stage 6)
- This prevents "gaming" the system by using narrow filters
- Full testing (multiple options per question) required to reach Confident/Mastered

**Selection strategies:**
- **Smart (Wanikani)**: Prioritizes due cards, then new cards, then future cards
- **Sequential**: Shows cards in fixed order (still tracks SRS progress)

**UI indicators:**
- Stage shown as 8 dots with current stage filled
- Lock icon appears when advancement is capped
- Filter icon filled when not all card types selected

### Testing Gotchas
- Creating `FlashcardSettings` or `LearningModel` instances in **new** test files causes CoreAudio malloc crashes in the test host
- Existing test files (e.g., `LearningModelTests`) work because they were part of the original target setup
- For new test files, test pure data logic only — avoid instantiating `@Observable` model classes
- The project uses `PBXFileSystemSynchronizedRootGroup` — new source files are auto-discovered, no pbxproj edits needed

### Build Notes
- **Deployment target:** iOS 17.0 (supports iPhone XR and newer)
- **Simulator:** Use `iPhone 17` (available on this system)

### Reference Tab Status
- Implemented: Consonants, Vowels, Tone Rules, Tone Marks, Clusters
- Each type has search filtering and type-specific filter chips
- Sound playback enabled for all types


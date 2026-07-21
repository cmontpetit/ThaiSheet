# ThaiSheet Architecture

## Overview

ThaiSheet follows a lightweight service-oriented SwiftUI architecture. Views observe `@Observable` services directly — no MVVM indirection. Dependencies are injected via SwiftUI's `@Environment`.

## Layers

```
ContentView.swift          App shell: TabView, navigation state, view modifiers
    |
    +-- Views/             SwiftUI views (flashcards, reference browser, settings)
    +-- Models/            Data types, settings, learning state
    +-- Services/          Business logic: card management, audio, data loading
    +-- Resources/         JSON data files and sound files
```

### Models (`ThaiSheet/Models/`)

**Data types** — loaded from JSON via `BundleLoader`:
- `Consonant`, `Vowel`, `ToneMark`, `ToneRule`, `Cluster` — Thai character data
- `VowelCard`, `ToneMarkCard`, `ToneRuleCard` — flashcard wrappers that pair data with quiz metadata
- `FlashcardItem` — enum unifying all card types (`case consonant(Consonant)`, etc.)
- `FlashcardType` — `CaseIterable` enum for card categories, with `label` property. Also owns persisted progress-ID construction (`cardId(for:)`) — IDs are stored in user data, never build them by hand
- `ThaiColors` — shared tone/class color mapping
- `ThaiDisplay` — display forms for the ◌ placeholder, combining-mark search normalization

**State:**
- `FlashcardSettings` (`@Observable`) — filter toggles and preferences, persisted via `didSet`. Accepts a `KeyValueStore` for testability. Also owns the dev-only language override (`Bundle.appLanguage`).
- `LearningModel` (`@Observable`) — SRS progress tracking (`CardProgress` per card). Accepts a `KeyValueStore`.
- `CardProgress` — per-card SRS stage, review timestamps, streak
- `KeyValueStore` — protocol abstracting the UserDefaults API (`UserDefaults` conforms); `SyncedKeyValueStore` mirrors an allowlist of settings and progress to `NSUbiquitousKeyValueStore` after opt-in, reconciling existing cloud data before seeding missing values

### Services (`ThaiSheet/Services/`)

- **`FlashcardManager`** (`@Observable`) — owns card filtering, ordering, navigation. Delegates card selection to a `CardSelectionStrategy`.
- **`CardSelectionStrategy`** (protocol) — `SequentialStrategy` (fixed order) and `WanikaniStrategy` (SRS-prioritized).
- **`AudioPlayer`** — app-owned service conforming to `AudioPlaying`, created by `ThaiSheetApp` and injected via `@Environment(\.audioPlayer)`. Uses `SoundType` enum (`.consonant`, `.vowel`, `.toneMark`, `.toneRule`, `.cluster`) for unified `play`/`hasSound` methods.
- **`BundleLoader`** — generic JSON loading utility. All models use `BundleLoader.load(_:as:keyPath:)` instead of duplicated boilerplate.
- **`ThaiDataStore`** — centralizes the bundled reference and flashcard data shared by `FlashcardManager` and `CheatsheetBrowserView`; injected via `@Environment(\.thaiData)`.

### Views (`ThaiSheet/Views/`)

**Flashcard views** — one per card type, each with its own multi-step quiz flow:
- `ConsonantFlashcardView` — class, initial sound, final sound, transcription
- `VowelFlashcardView` — duration, form, sound
- `ToneMarkFlashcardView` — tone identification
- `ToneRuleFlashcardView` — consonant class, vowel duration, ending, tone
- `ClusterFlashcardView` — type, sound

**Reference views** — row views for the browse/search tab:
- `ConsonantRowView`, `VowelRowView`, `ToneMarkRowView`, `ToneRuleRowView`, `ClusterViews` (matrix + grid cells)
- All playable items share one interaction, via `PlayableItemModifier`: tap plays the sound (details sheet when there is none), long press opens the details sheet. The modifier also carries the VoiceOver semantics (label, hint, button trait) — use it instead of raw gestures.

**Shared components:**
- `FlashcardComponents.swift` — `FlashcardResultCard`, `FlashcardSummaryRow`, `FlashcardNextButton`, `NavigableTapArea`, etc.
- `PlayableItemModifier` — tap-to-play/long-press-details gesture + accessibility for reference items
- `FilterChipView` — reusable filter chip
- `ReferenceItemSheet` — detail sheet for reference items

**Screens:**
- `CheatsheetBrowserView` — reference tab with search and section navigation
- `FlashcardFilterView`, `SettingsView` — settings sheets
- `SRSStatsView` — learning progress statistics

### App Shell (`ContentView.swift`)

- `ContentView` — `TabView` with flashcards and reference tabs
- `FlashcardsView` — card display with toolbar, delegates to type-specific flashcard views
- Navigation state uses `[FlashcardType: String]` dictionaries for cross-tab communication (highlight in reference, jump to flashcard)
- View modifiers (`FlashcardsSheetModifier`, `FlashcardsNavigationModifier`, `FlashcardsSettingsModifier`) keep the body lean

## Dependency Injection

| Dependency | Mechanism |
|---|---|
| `AudioPlaying` | `@Environment(\.audioPlayer)` — protocol, mockable |
| `LearningModel` | `@Environment(\.learningModel)` |
| `ThaiDataStore` | `@Environment(\.thaiData)` |
| `FlashcardSettings` | Canonical instance passed into the app shell and manager, and injected via `@Environment(\.flashcardSettings)` for settings-aware detail views; accepts `KeyValueStore` in init |
| `FlashcardManager` | Passed as parameter to `FlashcardsView` |

## Data Flow

```
JSON files  -->  BundleLoader  -->  Model types
                                       |
FlashcardSettings  -->  FlashcardManager  -->  FlashcardItem
                              |
                    CardSelectionStrategy
                              |
                        current card  -->  *FlashcardView
                              |
                        LearningModel  <--  quiz result (correct/incorrect)
```

## Key Patterns

- **`@Observable` + `didSet`** for UserDefaults persistence (no Combine, no computed getters)
- **Protocol + Environment** for testable dependency injection (AudioPlaying)
- **`CaseIterable` enums** with properties to avoid scattered switch statements
- **Generic utilities** (`BundleLoader`) to eliminate boilerplate across model types
- **Dictionary-keyed state** (`[FlashcardType: String]`) instead of per-type @State explosion

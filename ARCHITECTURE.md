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
- `FlashcardType` — `CaseIterable` enum for card categories, with `label` property
- `ThaiColors` — shared tone/class color mapping

**State:**
- `FlashcardSettings` (`@Observable`) — filter toggles and preferences, persisted via `UserDefaults` `didSet`. Accepts `UserDefaults` instance for testability.
- `LearningModel` (`@Observable`) — SRS progress tracking (`CardProgress` per card)
- `CardProgress` — per-card SRS stage, review timestamps, streak

### Services (`ThaiSheet/Services/`)

- **`FlashcardManager`** (`@Observable`) — owns card filtering, ordering, navigation. Delegates card selection to a `CardSelectionStrategy`.
- **`CardSelectionStrategy`** (protocol) — `SequentialStrategy` (fixed order) and `WanikaniStrategy` (SRS-prioritized).
- **`AudioPlayer`** — singleton conforming to `AudioPlaying` protocol. Injected via `@Environment(\.audioPlayer)`. Uses `SoundType` enum (`.consonant`, `.vowel`, `.toneMark`, `.toneRule`, `.cluster`) for unified `play`/`hasSound` methods.
- **`BundleLoader`** — generic JSON loading utility. All models use `BundleLoader.load(_:as:keyPath:)` instead of duplicated boilerplate.

### Views (`ThaiSheet/Views/`)

**Flashcard views** — one per card type, each with its own multi-step quiz flow:
- `ConsonantFlashcardView` — class, initial sound, final sound, transcription
- `VowelFlashcardView` — duration, form, sound
- `ToneMarkFlashcardView` — tone identification
- `ToneRuleFlashcardView` — consonant class, vowel duration, ending, tone
- `ClusterFlashcardView` — type, sound

**Reference views** — row views for the browse/search tab:
- `ConsonantRowView`, `VowelRowView`, `ToneMarkRowView`, `ToneRuleRowView`, `ClusterRowView`

**Shared components:**
- `FlashcardComponents.swift` — `FlashcardResultCard`, `FlashcardSummaryRow`, `FlashcardNextButton`, `NavigableTapArea`, etc.
- `FilterChipView` — reusable filter chip
- `ReferenceItemSheet` — detail sheet for reference items

**Screens:**
- `CheatsheetBrowserView` — reference tab with search and section navigation
- `FlashcardFilterView`, `FlashcardSettingsView` — settings sheets
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
| `FlashcardSettings` | Passed as parameter; accepts `UserDefaults` in init |
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

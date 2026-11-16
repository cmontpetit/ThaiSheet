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
- All playable items share one interaction, via `PlayableItemModifier`: tap plays the sound and selects the inline detail on expanded containers; compact containers open a sheet when there is no sound. Long press and the VoiceOver Show details action always request details. The modifier also carries practice concealment and selected-item semantics — use it instead of raw gestures.
- `ReferenceSelection` owns the exact selected cell and sheet/pane handoff outside the rows. Vowel forms share a reading ID; tone-mark class columns have separate reading IDs. Search, filters, and section changes clear a selection that is no longer visible.
- `ReferenceBrowserLayout` adds an inline pane when the container can fit a 500-point table and 320-point detail (both scale with Dynamic Type), with at least 440 points of height. The browser stays in the same view-tree location through resizing. `ReferenceDetailPane` removes all answer content and actions whenever `practiceMode.isConcealed(selectedItem.concealID)` is true, including after a second tap or practice activation.
- Narrowing a concealed pane retains its selection without automatically opening an answer sheet. Compact long-press details remain an explicit route to the answer, as before.
- The Reference split decision measures the container independently of keyboard safe-area changes. The table and detail scroll areas still avoid the keyboard; focusing search must not trigger a sheet handoff.
- Active search suppresses automatic compact detail sheets during rotation, preserving selection and unfinished Thai input. Explicit compact Show details requests end search before presenting. Automatic sheet/pane handoffs disable their own modal animations so they do not compete with the system's rotation animation.
- Reference uses a single native search field in an always-visible navigation-bar drawer. Search presentation avoids hiding toolbar content so the Reference actions remain available while editing.

**Shared components:**
- `FlashcardLayout` — a single `AnyLayout` view tree, stacked in narrow/short containers and arranged in two columns when there is room. Minimum column width scales with Dynamic Type; layout changes preserve quiz view identity and ease between arrangements over 0.25 seconds (immediate with Reduce Motion).
- `QuizOptionCache` — keeps randomized choices for the active card ID and romanization scheme. Reappearing tabs reuse the same choices; changing the quiz context regenerates them.
- `FlashcardComponents.swift` — `FlashcardResultCard`, `FlashcardSummaryRow`, `FlashcardNextButton`, `NavigableTapArea`, etc.
- `PlayableItemModifier` — tap-to-play/long-press-details gesture + accessibility for reference items
- `FilterChipView` — reusable filter chip
- `ReferenceItemSheet` — shared detail content for compact sheets and the inline Reference pane; sheet detents and dismissal apply only to sheet placement

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

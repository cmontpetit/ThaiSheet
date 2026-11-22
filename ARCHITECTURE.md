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
- Leaving Reference cancels automatic sheet intent and preserves the selected cell. Returning after an off-tab fold highlights that cell in the compact table and waits for an explicit detail request; returning wide restores the inline pane. `ReferenceViewport` reads the live owning-controller bounds from a probe outside `TabView`. Automatic sheets stay suppressed at the returned viewport size regardless of stale child measurements; a genuine viewport resize while Reference is active rearms handoff. Compact selection outlines and VoiceOver selection apply only to cells retained after folding. An explicit compact details request clears that fold marker, so ordinary compact rows do not stay selected after their sheets close.
- The Reference split decision measures the container independently of keyboard safe-area changes. The table and detail scroll areas still avoid the keyboard; focusing search must not trigger a sheet handoff. A cancellable task coalesces initial safe-area layout passes before applying presentation changes, so a superseded short-height measurement cannot leave a compact popup over an expanded pane.
- Active search suppresses automatic compact detail sheets during rotation, preserving selection and unfinished Thai input. Explicit compact Show details requests end search before presenting. Automatic sheet/pane handoffs disable their own modal animations so they do not compete with the system's rotation animation.
- `ReferenceSearchField` hosts one persistent native `UISearchBar` above the adaptive browser with system field sizing and appearance. Only the field's clear-text X is shown; the separate cancel X is omitted. The query stays visible when editing ends or the app tabs, sections, and container size change. It does not use navigation-bar search presentation, so searching cannot replace the toolbar actions with overflow. Its coordinator preserves marked Thai input during SwiftUI updates and keeps focus separate from the filtering query. The keyboard's Search key ends focus without clearing the query; there is no custom keyboard toolbar. On iPad the system keyboard also supplies its own dismiss key. Reference scroll areas support interactive keyboard dismissal, and leaving the Reference tab ends search focus.
- While search is focused, its coordinator temporarily observes taps in the owning window to end editing outside the search bar. The observer excludes the search bar and keyboard, permits simultaneous recognition, and neither cancels nor delays touches, so rows and controls still respond on the first tap. It uses the same query-preserving dismissal path as the Search key and is removed when editing ends or the field is dismantled.

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
- Cross-tab navigation carries the exact `ReferenceItem` into Practice and uses `[FlashcardType: String]` for highlights in Reference
- View modifiers (`FlashcardsSheetModifier`, `FlashcardsNavigationModifier`) keep the body lean
- `FlashcardDeckSyncModifier` on the `TabView` is the one path from settings to the deck: it observes `FlashcardSettings.deckSettings` and calls `FlashcardManager.syncDeck()`, so a change from either tab applies whether or not Flashcards has been shown. The `.syncedStoreDidChange` handler calls `FlashcardManager.reloadFromSyncedStore()` (settings, then progress, then the deck)

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
FlashcardSettings.deckSettings  --syncDeck()-->  FlashcardManager.filteredCards (applied deck)
                                                       |
                         CardSelectionStrategy, position count, SRSStatsView, QuestionCap
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

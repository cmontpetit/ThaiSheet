# ThaiSheet

Instructions for AI coding agents and new contributors.

## About ThaiSheet

iOS quick reference to help learn to read Thai, based on a comprehensive cheatsheet.
(Renamed from Aksorn.) The quick-lookup reference is the primary feature — an app
you reach for to find script info fast; flashcards are complementary practice.
The app opens on the Reference tab.

**Target users:** Thai language learners (beginner to intermediate)

**Key features:**
- **Reference tab** (first/default): Browse cheatsheet clips with search by character characteristics.
- **Flashcard tab**: Complementary practice — cards showing Thai characters with multiple-choice questions about their characteristics. Uses Wanikani-style SRS (spaced repetition) to optimize learning.

**Platforms:** iPhone, iPad

**Note:** On-device LLM (Foundation Models) - TBD if needed.

## Project Resources

- **Source cheatsheet images:** `external-resources/` (project root) — kept LOCAL ONLY, gitignored and purged from history: the cheat sheet is copyrighted Udemy course material and must not be committed. The app's data lives in `ThaiSheet/Resources/cheatsheet/*.json` (facts restructured, corrected, and extended — see data deviations below)
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
# Build for simulator (use an available simulator, e.g. iPhone 17)
xcodebuild -project ThaiSheet.xcodeproj -scheme ThaiSheet -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run tests
xcodebuild -project ThaiSheet.xcodeproj -scheme ThaiSheet -destination 'platform=iOS Simulator,name=iPhone 17' test

# Verify an App Store release build has no coverage instrumentation
scripts/check_release_binary.sh /path/to/ThaiSheet.app
```

## Project Conventions

### Architecture
- See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation

### @Observable and UserDefaults
- `FlashcardSettings` and `LearningModel` use `@Observable` with stored properties and `didSet` for persistence
- Both accept a `KeyValueStore` as init param (default `.standard`) for testability; `SyncedKeyValueStore` dual-writes UserDefaults + NSUbiquitousKeyValueStore for iCloud sync
- **Important:** Computed properties bypass `@Observable` tracking - always use stored properties
- Pattern: `var setting: Bool { didSet { defaults.set(setting, forKey: "key") } }`
- Initialize from the store in `init()`, not via computed getters

### Localization
- String catalog: `ThaiSheet/Localizable.xcstrings` (source `en`, translated `fr`)
- SwiftUI `Text("literal")` and `LocalizedStringKey` params localize automatically (they follow the environment locale)
- Every `String(localized:)` display string MUST pass `bundle: .appLanguage` — otherwise it follows the system language instead of the dev language picker
- Data identifiers from JSON ("Low", "Falling", "Dead/None", …) are displayed via `String(localized: String.LocalizationValue(value), bundle: .appLanguage)` (see `LocalizedOption`); comparison/quiz logic always uses the raw values, only display localizes
- Dynamic keys are not auto-extracted: add them to the xcstrings by hand (extractionState `"manual"`). CLI builds don't sync the catalog
- The Settings language picker is DEV-ONLY (`#if DEBUG`); release always follows the system language (`resolvedLocale` ignores the override, since a value could arrive via iCloud sync from a debug build). Two mechanisms switch together: `.environment(\.locale, settings.resolvedLocale)` for `Text`, and `Bundle.appLanguage` (kept in sync by `appLanguage.didSet` in FlashcardSettings.swift) for `String(localized:)`
- Tone annotations use Paiboon-style diacritics everywhere (grave = low, unmarked = mid, acute = high, circumflex = falling, caron = rising) — in the consonant transcriptions (khǎaw khài), on the tone answer buttons, and in the reference tone tables (`ThaiColors.toneDiacritic` / `StyledToneText`, shown on the ◌ placeholder). Language-neutral by design, nothing to translate. Code matching transcription prefixes must fold diacritics (`.folding(options: .diacriticInsensitive)`)
- Reference tab labels use `shortLabel` abbreviations when search counts are appended ("Cons. (12)") — the segmented control gives every segment equal width, so full names would truncate
- Pedagogical notes in `Resources/cheatsheet/*.json` are localized IN THE DATA MODEL with per-language subkeys (scalar notes as `{"en": …, "fr": …}` via `LocalizedText`, vowel notes as `"notes": {"en": {…}, "fr": {…}}`), resolved through `Bundle.appLanguageCode` with English fallback — never via the UI catalog. NOT yet localized: the `sounds.en` columns (use the same mechanism if/when translated)

### Interpreting the cheatsheet and clip files
- The cheatsheet is interpreted and stored as a data model in the app using UTF characters, with all of their characteristics.
- The clip-* files are just subsets of the cheatsheet-complete png file, for easier processing.
- The consonants "initial" and "final" columns are the sounds that they would sound like in English.
- The vowels "sound" column has the same purpose as the consonants initial and final columns.
- In the model, these two columns should be marked as English, since a French version, for instance, may have different letters.
- The placeholder "◌" (U+25CC dotted circle) is replaced with "ก" in JSON data.

### Data deviations from the source cheatsheet (audited July 2026)
The app's data intentionally differs from the source cheat sheet (`external-resources/complete-cheatsheet.png`, local only) where the PNG is wrong:
- ซ final sound: PNG says "-s" → app uses "-t" (Thai has no final /s/)
- ย/ว finals: PNG "[vowel]" → app "-y"/"-w"
- Added หญ- to silent ห combinations (missing from PNG; หญิง/ใหญ่/หญ้า)
- Added ฦ/ฦๅ (obsolete letters, not in PNG)
- Tone-mark table: NO no-mark row (one was once added as Mid/Mid — wrong for high class, whose unmarked live syllables are Rising; unmarked syllables belong to the tone-rules table). ๊/๋ are mid-class only (the PNG groups mid/high). Classes are represented as separate Low/Mid/High columns with fixed example consonants ค/ก/ข
- ช้าง transcription: PNG "chang" → "chaang" (long vowel)
- The PNG's 7-row tone rule table is CORRECT — do not add rules (a bogus "High+Long+Dead→Falling" was once introduced and removed; high-class dead syllables are always Low tone)
- Cluster romanization follows the consonant scheme (g-/dt-/bp-): กร- = gr-, ตร- = dtr-, ปร- = bpr-; aspirated onsets keep the h (ขร-/คร- = khr-, พร- = phr-, พล- = phl-). Exception: ผล- stays "pl-" pending word-specific verification (ผลิ is a cluster; ผลิต/ผลึก are not) — see https://github.com/cmontpetit/ThaiSheet/issues/7 before "fixing" it
- กำ (sara am) is Short/Closed ONLY — ◌ำ is a short vowel + final /m/; น้ำ-style lengthening is a lexical exception (noted in the data), not a Long form. Do not re-add the Long/Open duplicate

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
- `ThaiSheet/Models/` - Data models (Consonant, Vowel, ToneRule, ToneMark, Cluster, VowelCard, ToneMarkCard, ToneRuleCard), FlashcardItem, FlashcardSettings, LearningModel, CardProgress, ThaiColors, ThaiDisplay
- `ThaiSheet/Views/` - SwiftUI views (CheatsheetBrowserView, flashcard views, row views, FlashcardComponents, SRSStatsView, FilterView, SettingsView)
- `ThaiSheet/Services/` - AudioPlayer (protocol + environment injection), BundleLoader, CardSelectionStrategy (Sequential/Wanikani), FlashcardManager, ThaiDataStore
- `ThaiSheet/Resources/` - JSON data files and sounds

### Sound Files
- Location: `ThaiSheet/Resources/sounds/`
- Naming: `cheat_sheet_{type}_{key}.mp3` (e.g., `cheat_sheet_consonant_ก.mp3`, `cheat_sheet_vowel_กัน.mp3`)
- Types: `consonant`, `vowel`, `tone_mark`, `tone_rule`, `cluster`, `sample_word`
- Audio injection: `AudioPlaying` protocol via `@Environment(\.audioPlayer)` — never use `AudioPlayer.shared` directly in views
- The Audio setting selects one source for all sounds: Recorded voice uses bundled Google MP3s (including sample words); Device voice uses live `AVSpeechSynthesizer` with a Thai system voice. If no Thai system voice is available, playback falls back to the recorded set.
- Vowel audio always speaks the visible per-form pronunciation word for both sources. The current data falls back to the existing sample word when no dedicated `pronunciations` entry exists; forms without a real-word mapping remain silent.
- Do not bundle audio recorded from Apple System Voices. Apple speech is synthesized live on-device only; bundled recordings remain Google Cloud TTS output.

### Sound File Generation
- Script: `scripts/generate_sounds.py` (uses Google Cloud Text-to-Speech)
- First-time setup:
  ```bash
  cd scripts && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
  gcloud auth application-default login
  ```
- After setup, just activate and run:
  ```bash
  source scripts/venv/bin/activate
  python3 scripts/generate_sounds.py --all --dry-run --check-files
  python3 scripts/generate_sounds.py --all --force --normalize-lufs -18 --check-files
  # Or specific types: --consonants, --vowels, --tone-marks, --tone-rules
  ```
- Default generation voice: `th-TH-Neural2-C`. The current vowel pronunciation words use `th-TH-Chirp3-HD-Kore`; the rest of the bundled set uses Neural2-C. Use an explicit `--voice-name` when replacing either set.
- The bundled Neural2-C files used `--volume-gain-db 6`; the Kore vowel words use `--normalize-lufs -18`. LUFS normalization includes a -1.5 dB true-peak limit; update `scripts/recorded_audio_metadata.json` when a candidate replaces either set.
- Non-dry generation validates raw responses before post-processing. Clips shorter than 0.35 seconds or quieter than -24 dBFS peak are rejected and synthesized again up to four times. This catches generative TTS failures such as a near-silent `กึ`; it does not verify pronunciation or tone.
- Exact duplicate synthesis inputs reuse the first processed response within a generation run, producing byte-identical MP3s without additional TTS requests.
- The canonical list of 388 expected sounds and synthesis inputs lives in `scripts/sound_inventory.py`. Generation, tests, and the website catalog must use that inventory rather than independently deriving filenames.
- Custom `--output-dir` paths are restricted to `scratchpad/`, allowing candidate voices to be generated without risking bundled production audio.
- Use repeatable `--sound-id` arguments for targeted regeneration (for example `--sound-id 'vowel:กึ-:short_closed'`). Stable IDs come from the canonical inventory.
- Reference sample words are deduplicated by Thai word and generated as `cheat_sheet_sample_word_{word}.mp3`; `--sample-words` generates only that set and `--all` includes it.
- The public catalog is `docs/sounds.html`. Local previews use working-tree audio; serve the repository root and open `/docs/sounds.html` so `ThaiSheet/Resources/sounds/` is available.
- Existing MP3s are skipped unless `--force` is passed
- Use `--check-files` with `--all` to catch stale or missing bundled MP3s before release
- ฤ- (the "ri" reading) uses the explicit pronunciation word `ฤทธิ์`; never synthesize the ambiguous bare form.
- Tone mark sounds: 8 files using fixed consonants (ค low, ก mid, ข high class) + า vowel

#### Comparing TTS providers

Use `scripts/generate_tts_comparison.py` for local voice auditions. It reads the
diagnostic cases in `scripts/tts_comparison_manifest.json`, writes only beneath
the gitignored `scratchpad/tts-comparison/` directory, and creates an `index.html`
with side-by-side audio controls. It never writes bundled production sounds.

```bash
source scripts/venv/bin/activate
python3 scripts/generate_tts_comparison.py --force

# Optional Azure comparison (credentials are read only from the environment)
AZURE_SPEECH_KEY=... AZURE_SPEECH_REGION=... \
  python3 scripts/generate_tts_comparison.py --provider google --provider azure --force
```

The default Google columns are the bundled set's Neural2-C voice and two current
Chirp 3 HD candidates. Azure defaults to Premwadee, Achara, and Niwat. Keep
provider output local until it has been reviewed by a native Thai speaker and
its distribution terms have been confirmed.

For a complete candidate set, generate a local current-versus-candidate review
page and acoustic report with:

```bash
python3 scripts/generate_sound_review.py \
  --candidate-dir scratchpad/kore-candidate \
  --candidate-voice th-TH-Chirp3-HD-Kore
```

To audit the vowel pronunciation-word mapping, generate the 73-variant curation
page with `python3 scripts/generate_vowel_pronunciation_review.py`. It compares
the bundled word audio with the candidate recording, preserves duplicate
spellings as separate short/long variants, and leaves forms with no real-word
candidate silent. The page automatically flags overlong and internally
segmented one-word clips, but listening review remains required because extra
generated speech may be fluent. Treat the mapping and recordings as provisional
until that review is complete.

#### Public pronunciation catalog

The GitHub Pages catalog at `docs/sounds.html` reads generated
`docs/sounds-data.js`. Generate it with `python3 scripts/generate_sound_catalog.py`.
The data includes SHA-256 revisions for every MP3, so any audio change makes
`--check` fail until the catalog is refreshed. CI runs the inventory tests and
catalog freshness check. The page streams the existing files from GitHub raw
URLs with `preload="none"`; do not copy the MP3 set into `docs/`.

### Flashcard Design Decisions
- **Tone Marks**: Use fixed consonants matching the reference (ค low, ก mid, ข high)
  - 8 total cards: 2 low (ค่า, ค้า) + 4 mid (ก่า, ก้า, ก๊า, ก๋า) + 2 high (ข่า, ข้า)
  - No cards for unmarked syllables — those follow the tone rules
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
- **Simulator:** any available iPhone simulator (e.g. `iPhone 17`)
- **SourceKit/editor diagnostics** like "Cannot find type X in scope" for types defined in other files are cross-file resolution noise, NOT real errors — always verify with `xcodebuild`
- Release builds must keep `ENABLE_CODE_COVERAGE = NO`; before App Store submission, run `scripts/check_release_binary.sh` against the archived `.app` product to catch LLVM coverage/profile sections and confirm `ITSAppUsesNonExemptEncryption = false`

### App Icon
- Generated by `scripts/generate_icon.py` (Pillow; writes the three PNGs into `Assets.xcassets/AppIcon.appiconset/`) — edit the script and re-run rather than editing PNGs
- Three variants wired in Contents.json: light, dark, and tinted (tinted must stay grayscale per Apple's spec; keep its chip luminances lighter than the glyph)
- Artwork must be FULL-BLEED 1024×1024 — no pre-rounded corners or outer padding; iOS applies its own mask (a baked-in rounded rect shows a double-rounding artifact on device)
- Design: cheatsheet card + table rules + bold Thonburi ก + three consonant-class color chips (green/yellow/red = low/mid/high, matching `ConsonantClass.color`)
- The website favicon/touch icons (`docs/icon-{32,180,256}.png`) are resized copies — after changing the icon, regenerate them: `for sz in 32 180 256; do sips -z $sz $sz ThaiSheet/Assets.xcassets/AppIcon.appiconset/AppIcon.png --out docs/icon-$sz.png; done`

### App Store and Open Source Notes
- App Store metadata draft lives in `APP_STORE_METADATA.md`; privacy/support/security docs live in `PRIVACY.md`, `SUPPORT.md`, and `SECURITY.md`
- The App Store privacy position is: no ads, analytics, tracking, or third-party iOS SDKs; learning progress/settings are local unless optional iCloud Sync is enabled
- Before public release, confirm rights and attribution for JSON learning data and screenshots. Bundled MP3s: DONE — regenerated with official Google Cloud Text-to-Speech credentials (commit 46c0ffd, July 2026)
- Do not commit `external-resources/`; source cheatsheet images are local-only copyrighted reference material

### Verifying UI in the simulator (no UI automation)
`xcrun simctl` cannot tap or scroll, so to see a specific screen:
- Temporarily change `@State` defaults and rebuild — e.g. `selectedTab: AppTab = .reference` in ContentView.swift, `selectedType: CheatsheetEntryType = .vowels` in CheatsheetBrowserView.swift — then `simctl install`/`launch` and `simctl io <device> screenshot`. Revert afterward
- Persisted settings can be injected as launch arguments (NSArgumentDomain overrides the plist): `xcrun simctl launch <device> net.montpetit.thaisheet -fc_appLanguage en -AppleLanguages "(fr)"`. Writing the container plist by hand does NOT work (cfprefsd ignores it), and `defaults write` only works after the app has created its prefs domain
- **Stale-build trap:** xcodebuild sometimes reports BUILD SUCCEEDED without recompiling a just-edited file — and fresh file mtimes can hide stale content (the debug dylib gets relinked from stale objects). Definitive check: `nm ThaiSheet.app/ThaiSheet.debug.dylib | grep <aNewSymbolName>` (the real code is in the dylib; the main executable is a stub). If the symbol is missing, `xcodebuild clean build`. Alternatively add an unmistakable marker string to a `body` literal and rebuild: marker visible = pipeline fresh
- Zoom screenshots before judging Thai glyph details — small renderings mislead

### Reference Tab Status
- Four segments (`CheatsheetEntryType`): Consonants, Vowels, Clusters, Tones — the Tones segment combines tone marks and tone rules; the rules table is captioned "Unmarked syllable tone rules" (the 7 rules apply only to syllables WITHOUT a tone mark)
- Each type has search filtering and type-specific filter chips
- Sound playback enabled for all types
- Interaction convention: tap on a playable item plays its sound (opens the details sheet when it has none); long press opens the details sheet (play/practice). Implemented by `PlayableItemModifier`, which also carries the VoiceOver semantics — never attach raw tap/long-press gestures to reference items

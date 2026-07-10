# Changelog

All notable changes to ThaiSheet will be documented in this file.

## Unreleased

- Unified reference-item interaction: tap plays the sound, long press opens the details sheet, consistently across all reference segments.
- Restored VoiceOver support on reference items (labels, hints, button traits) and localized the new hints.
- Added haptic feedback on flashcard answers.
- Repositioned the app as a reference first, with flashcards as complementary practice (About tagline, README, docs).
- Protected dynamically looked-up localization keys from catalog cleanup; removed dead keys.
- Learning-progress and bundled-data load failures are now logged instead of silent; corrupted progress no longer risks being overwritten.
- Prepared repository metadata for first App Store submission.
- Added privacy, support, and security documentation.
- Disabled Release code coverage instrumentation for App Store builds.
- Isolated strategy tests from the app's UserDefaults domain.

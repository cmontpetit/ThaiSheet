# App Store Metadata Draft

This file is a working draft for App Store Connect. Review it before submission, especially privacy, support, and content-rights answers.

## App Information

- Name: ThaiSheet
- Subtitle: `Thai script quick reference` (27/30 chars)
- Primary category: Education
- Secondary category: Reference
- Bundle ID: `net.montpetit.thaisheet`
- SKU: `thaisheet`
- Version: `1.1`
- Build: `6`
- Copyright: `2026 Claude Montpetit`
- Pricing: Free
- In-App Purchases: None

## URLs

- Privacy Policy URL: https://cmontpetit.github.io/ThaiSheet/privacy.html
- Support URL: https://cmontpetit.github.io/ThaiSheet/support.html
- Marketing URL (optional): https://cmontpetit.github.io/ThaiSheet/

(Verified live on July 20, 2026.)

## Description

ThaiSheet is a quick reference to help you learn to read Thai script: look up consonants, vowels, consonant clusters, tone marks, and tone rules in the classic cheat-sheet tables — searchable, filterable, and with pronunciation audio throughout.

Tap any character, cluster, tone example, or most vowel forms to hear it; the five vowel forms without a real-word audio mapping open their details instead. Look up a consonant's class, its initial and final sounds, or which tone a syllable takes — the way the tables teach it.

When you want to practice, complementary flashcards quiz you on what you look up, with a Wanikani-style spaced repetition system (SRS) tracking each card from Learning to Mastered.

- Complete script reference: 44 consonants, 33 vowels, consonant clusters, tone marks, and the 7 tone rules
- Pronunciation audio throughout (five vowel forms are intentionally text-only)
- Search by character or sound; filter by class, duration, or type
- Multiple-choice flashcards with SRS and progress statistics
- Optional iCloud sync of progress and settings
- English and French interface
- No account, no ads, no analytics, no tracking — and open source

ThaiSheet is a companion to whatever course or textbook you use: it won't replace study, but it keeps everything you need to decode Thai script one tap away.

## Keywords

Thai,Thailand,language,script,alphabet,reading,flashcards,SRS,tone,vowels,consonants

## Promotional Text

The Thai script cheat sheet as an app: reference tables, pronunciation audio, and SRS flashcards.

## What's New

- Choose from three recorded Thai pronunciation voices, or use an installed Thai system voice.
- Set a different pronunciation voice for individual reference items.
- Practice reading by hiding transcriptions until you reveal them.
- Improved audio fallback behavior and VoiceOver accessibility.

## French Store Metadata — DEFERRED

Decision (July 2026): the first submission ships with English (U.S.) store metadata
only; the app's French UI localization ships regardless. Add this French listing in a
later update — as **French (Canada)** first (the Canadian storefront indexes fr-CA
keywords), optionally duplicated to French (France).

- Subtitle: `Aide-mémoire thaï + audio` (25)
- What's New: `Première version.`
- Keywords: `thaï,Thaïlande,langue,alphabet,lecture,cartes,SRS,tons,voyelles,consonnes`
- Promotional text: `La feuille de référence du thaï en app : tableaux, audio et cartes SRS.`
- Description:

ThaiSheet est un aide-mémoire pour apprendre à lire l'écriture thaïe : retrouvez consonnes, voyelles, groupes de consonnes, signes de ton et règles de ton dans les tableaux classiques — avec recherche, filtres et audio de prononciation partout.

Touchez un caractère, un groupe, un exemple de ton ou la plupart des formes de voyelles pour l'entendre ; les cinq formes sans correspondance audio dans un mot réel ouvrent plutôt leur fiche. Retrouvez la classe d'une consonne, ses sons initial et final, ou le ton d'une syllabe — tels que les tableaux les enseignent.

Pour pratiquer, des cartes-éclair complémentaires vous interrogent sur ce que vous consultez, avec un système de répétition espacée (SRS) de style Wanikani qui suit chaque carte de « Apprentissage » à « Maîtrisé ».

- Référence complète : 44 consonnes, 33 voyelles, groupes de consonnes, signes de ton et les 7 règles de ton
- Audio de prononciation partout (cinq formes de voyelles sont volontairement sans audio)
- Recherche par caractère ou par son ; filtres par classe, durée ou type
- Cartes-éclair à choix multiples avec SRS et statistiques de progression
- Synchronisation iCloud optionnelle de la progression et des réglages
- Interface en anglais et en français
- Pas de compte, pas de pub, pas de suivi — et open source

ThaiSheet accompagne le cours ou le manuel de votre choix : il ne remplace pas l'étude, mais garde tout ce qu'il faut pour décoder l'écriture thaïe à portée de main.

## Review Notes

ThaiSheet does not require an account. All app features are available immediately after launch.

iCloud Sync is optional and can be toggled from Settings. The app uses Apple's iCloud key-value store only for learning progress and settings.

## Privacy Nutrition Label Draft

- Data collected: None by the developer.
- Tracking: No.
- Third-party advertising: No.
- Analytics: No.
- Optional iCloud Sync: Uses Apple's iCloud key-value store to sync learning progress and settings across devices for the same Apple ID. The developer does not operate a server for this data.

## Export Compliance Draft

The app does not implement custom encryption and sets `ITSAppUsesNonExemptEncryption` to `NO`.

## Age Rating Notes

No user-generated content, web browsing, purchases, gambling, violence, medical advice, or unrestricted internet access.

## Content Rights

- Learning data: the bundled JSON files are an independent compilation of factual
  information about the Thai script (character inventory, consonant classes, sounds,
  tone rules) expressed in the app's own structure and wording, with corrections and
  additions by the author (see "Data deviations" in CLAUDE.md). No third-party images,
  prose, or artwork are included.
- Audio: pronunciation MP3s were generated by the author with two text-to-speech
  providers, each under the author's own paid account whose terms grant a commercial
  license to use the generated audio in applications:
  - Google Cloud Text-to-Speech (voices Neural2-C and Chirp3-HD Kore).
  - ElevenLabs (voice Matilda, model eleven_v3) — the app's default voice.
  The app bundles all three voice sets and lets the user choose one in Settings.
  Attribution: "Audio generated by Google Cloud TTS and ElevenLabs" (also shown in
  the app's About screen credits). Keep the ElevenLabs subscription active while
  generating/maintaining audio; the commercial license applies to content produced
  while subscribed.
- Screenshots: captured from the app itself; no third-party content.

## Required Before Submission

- [x] Capture App Store screenshots for iPhone and iPad (`docs/screenshots/appstore-1.1/`, July 20, 2026).
- [x] Publish the GitHub repository and enable GitHub Pages (`main:/docs`).
- [x] Verify the privacy/support/marketing URLs above are live (HTTP 200, July 20, 2026).
- [x] Verify App Privacy declares no data collected and uses the published privacy URL.
- [x] Verify the age-rating questionnaire declares no social, chat, user-generated content, advertising, or unrestricted web access (4+ rating).
- [x] Regenerate bundled audio with official Google Cloud Text-to-Speech credentials (commit 46c0ffd, July 2026).
- [x] Document rights/attribution for learning data and audio (Content Rights above).
- [x] Run `scripts/check_release_binary.sh` on the unsigned 1.1 (5) Release product (passed July 20, 2026).
- [ ] Run `scripts/check_release_binary.sh` on the final signed 1.1 (6) archive before upload.
- [ ] Complete the account-level EU Digital Services Act trader-status declaration in Business.
- [ ] Optionally complete the App Accessibility questionnaire after VoiceOver and Dynamic Type device testing.
- [x] Create the App Store Connect app record.
- [ ] Upload and select build 6 for version 1.1.
- [ ] Create an internal TestFlight group, add build 6, and perform the upgrade/device test pass.
- [ ] Create the 1.1 App Store version, add the What's New text, and upload the new screenshots.

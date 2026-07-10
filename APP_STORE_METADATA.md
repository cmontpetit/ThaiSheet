# App Store Metadata Draft

This file is a working draft for App Store Connect. Review it before submission, especially privacy, support, and content-rights answers.

## App Information

- Name: ThaiSheet
- Subtitle: PICK ONE (30-char limit):
  - `Thai script reference & drills` (30)
  - `Read Thai: reference + audio` (28)
  - `Learn to read Thai script` (25 — current draft)
- Primary category: Education
- Secondary category: Reference
- Bundle ID: `net.montpetit.thaisheet`
- SKU: `thaisheet-ios`
- Version: `1.0`
- Build: `1`
- Copyright: `2026 Claude Montpetit`
- Pricing: Free
- In-App Purchases: None

## URLs

- Privacy Policy URL: https://cmontpetit.github.io/ThaiSheet/privacy.html
- Support URL: https://cmontpetit.github.io/ThaiSheet/support.html
- Marketing URL (optional): https://cmontpetit.github.io/ThaiSheet/

(Live once the repo is public and GitHub Pages is enabled on `main:/docs`.)

## Description

ThaiSheet is a focused reference to help you learn to read Thai script: the classic cheat-sheet tables for consonants, vowels, consonant clusters, tone marks, and tone rules — searchable, filterable, and with pronunciation audio throughout.

Tap any character, vowel form, cluster, or tone example to hear it. Look up a consonant's class, its initial and final sounds, or which tone a syllable takes — the way the tables teach it.

When you want to practice, complementary flashcards quiz you on what you look up, with a Wanikani-style spaced repetition system (SRS) tracking each card from Learning to Mastered.

- Complete script reference: 44 consonants, 33 vowels, consonant clusters, tone marks, and the 7 tone rules
- Pronunciation audio for every entry
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

Initial release.

## French (fr-FR) Store Metadata Draft

- Subtitle: `Référence pour lire le thaï` (27)
- Keywords: `thaï,Thaïlande,langue,alphabet,lecture,cartes,SRS,tons,voyelles,consonnes`
- Promotional text: `La feuille de référence du thaï en app : tableaux, audio et cartes SRS.`
- Description:

ThaiSheet est une référence pour apprendre à lire l'écriture thaïe : les tableaux classiques des consonnes, voyelles, groupes de consonnes, signes de ton et règles de ton — avec recherche, filtres et audio de prononciation partout.

Touchez un caractère, une forme de voyelle, un groupe ou un exemple de ton pour l'entendre. Retrouvez la classe d'une consonne, ses sons initial et final, ou le ton d'une syllabe — tels que les tableaux les enseignent.

Pour pratiquer, des cartes-éclair complémentaires vous interrogent sur ce que vous consultez, avec un système de répétition espacée (SRS) de style Wanikani qui suit chaque carte de « Apprentissage » à « Maîtrisé ».

- Référence complète : 44 consonnes, 33 voyelles, groupes de consonnes, signes de ton et les 7 règles de ton
- Audio de prononciation pour chaque entrée
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
- Audio: all pronunciation MP3s were generated by the author with Google Cloud
  Text-to-Speech under the author's own Google Cloud account; Google's terms permit
  using generated audio in applications. Attribution: "Audio generated with Google
  Cloud Text-to-Speech" (also shown in the app's About screen credits).
- Screenshots: captured from the app itself; no third-party content.

## Required Before Submission

- [x] Capture App Store screenshots for iPhone and iPad (`docs/screenshots/`, July 2026).
- [ ] Publish the GitHub repository and enable GitHub Pages (`main:/docs`).
- [ ] Verify the privacy/support/marketing URLs above are live.
- [x] Regenerate bundled audio with official Google Cloud Text-to-Speech credentials (commit 46c0ffd, July 2026).
- [x] Document rights/attribution for learning data and audio (Content Rights above).
- [x] Run `scripts/check_release_binary.sh` on a Release archive (passed July 10, 2026 — re-run on the final signed archive before upload).
- [ ] Create the App Store Connect app record and select the signed archive build.

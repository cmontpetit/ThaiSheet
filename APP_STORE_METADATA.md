# App Store Metadata Draft

This file is a working draft for App Store Connect. Review it before submission, especially privacy, support, and content-rights answers.

## App Information

- Name: ThaiSheet
- Subtitle: Learn to read Thai script
- Primary category: Education
- Secondary category: Reference
- Bundle ID: `net.montpetit.thaisheet`
- SKU: `thaisheet-ios`
- Version: `1.0`
- Build: `1`
- Copyright: `2026 Claude Montpetit`

## Description

ThaiSheet helps learners read Thai script with a focused reference browser, pronunciation audio, and flashcards for consonants, vowels, tone marks, tone rules, and consonant clusters.

Practice with a Wanikani-style spaced repetition system, review cards in sequence, filter the topics you want to study, and track progress across SRS stages. ThaiSheet includes English and French interface localizations and can optionally sync progress across your devices with iCloud.

ThaiSheet is open source and built without ads, analytics, tracking, or third-party iOS SDKs.

## Keywords

Thai,Thailand,language,script,alphabet,reading,flashcards,SRS,tone,vowels,consonants

## Promotional Text

Practice Thai script with reference tables, pronunciation audio, and SRS flashcards.

## What's New

Initial release.

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

## Required Before Submission

- Capture App Store screenshots for iPhone and iPad.
- Publish the GitHub repository or another public support page.
- Use `PRIVACY.md` as the hosted Privacy Policy URL once public.
- Regenerate bundled audio with official Google Cloud Text-to-Speech credentials and confirm rights/attribution for source learning data.
- Run `scripts/check_release_binary.sh` on the archived app product.
- Create the App Store Connect app record and select the signed archive build.

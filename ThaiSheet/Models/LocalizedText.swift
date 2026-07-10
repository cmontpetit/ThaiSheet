//
//  LocalizedText.swift
//  ThaiSheet
//

import Foundation

/// A user-facing data-model string with per-language variants, the same
/// pattern as `sounds.en`. Data notes live in the JSON (not the UI string
/// catalog), so they carry their translations inline and resolve against
/// the app display language, falling back to English.
struct LocalizedText: Codable {
    let en: String
    let fr: String?

    var localized: String {
        Bundle.appLanguageCode == "fr" ? (fr ?? en) : en
    }
}

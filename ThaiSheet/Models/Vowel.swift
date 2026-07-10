//
//  Vowel.swift
//  ThaiSheet
//

import Foundation

struct VowelForm: Codable {
    let closed: String?
    let open: String?
}

struct VowelSounds: Codable {
    let en: String
}

struct VowelNotes: Codable {
    let short_closed: String?
    let short_open: String?
    let long_closed: String?
    let long_open: String?

    enum CodingKeys: String, CodingKey {
        case short_closed, short_open, long_closed, long_open
    }
}

/// Per-language vowel notes (like `sounds.en`); untranslated languages
/// fall back to English per key
struct VowelNotesContainer: Codable {
    let en: VowelNotes
    let fr: VowelNotes?
}

enum VowelUsage: String, Codable {
    case common
    case uncommon
    case rare
    case archaic
}

struct Vowel: Codable, Identifiable {
    let short: VowelForm
    let long: VowelForm
    let sounds: VowelSounds
    let notes: VowelNotesContainer?
    let usage: VowelUsage?

    var id: String { sounds.en + "-" + allForms.joined(separator: "|") }

    /// Returns true if this vowel is uncommon, rare, or archaic
    var isUncommon: Bool {
        guard let usage = usage else { return false }
        return usage != .common
    }

    var sound: String { sounds.en }

    /// All existing written forms, in short-closed/short-open/long-closed/long-open order
    var allForms: [String] {
        [short.closed, short.open, long.closed, long.open].compactMap { $0 }
    }

    /// Returns true if this vowel has at least one written form for the duration
    func hasForm(for duration: VowelCard.VowelDuration) -> Bool {
        let form = duration == .short ? short : long
        return form.closed != nil || form.open != nil
    }

    func note(for duration: String, form: String) -> String? {
        guard let notes = notes else { return nil }
        let key: KeyPath<VowelNotes, String?>
        switch (duration, form) {
        case ("Short", "Closed"): key = \.short_closed
        case ("Short", "Open"): key = \.short_open
        case ("Long", "Closed"): key = \.long_closed
        case ("Long", "Open"): key = \.long_open
        default: return nil
        }
        if Bundle.appLanguageCode == "fr", let fr = notes.fr?[keyPath: key] {
            return fr
        }
        return notes.en[keyPath: key]
    }

    /// Returns true if the given form appears in both short and long positions
    func isDuplicate(form: String) -> Bool {
        let shortForms = [short.closed, short.open].compactMap { $0 }
        let longForms = [long.closed, long.open].compactMap { $0 }
        return shortForms.contains(form) && longForms.contains(form)
    }
}

struct VowelsData: Codable {
    let vowels: [Vowel]
}

extension Vowel {
    static func loadAll() -> [Vowel] {
        BundleLoader.load("vowels", as: VowelsData.self, keyPath: \.vowels)
    }
}

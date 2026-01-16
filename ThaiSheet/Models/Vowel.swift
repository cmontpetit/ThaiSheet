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

struct Vowel: Codable, Identifiable {
    let short: VowelForm
    let long: VowelForm
    let sounds: VowelSounds
    let notes: VowelNotes?

    var id: String { sounds.en + (short.closed ?? "") + (short.open ?? "") }

    var sound: String { sounds.en }

    func note(for duration: String, form: String) -> String? {
        guard let notes = notes else { return nil }
        switch (duration, form) {
        case ("Short", "Closed"): return notes.short_closed
        case ("Short", "Open"): return notes.short_open
        case ("Long", "Closed"): return notes.long_closed
        case ("Long", "Open"): return notes.long_open
        default: return nil
        }
    }

    var isRare: Bool {
        // Vowels with ฤ are rare
        let allForms = [short.closed, short.open, long.closed, long.open].compactMap { $0 }
        return allForms.contains { $0.contains("ฤ") }
    }
}

struct VowelsData: Codable {
    let vowels: [Vowel]
}

extension Vowel {
    static func loadAll() -> [Vowel] {
        guard let url = Bundle.main.url(forResource: "vowels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(VowelsData.self, from: data) else {
            return []
        }
        return decoded.vowels
    }
}

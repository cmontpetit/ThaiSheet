//
//  Vowel.swift
//  Aksorn
//

import Foundation

struct VowelForm: Codable {
    let closed: String?
    let open: String?
}

struct VowelSounds: Codable {
    let en: String
}

struct Vowel: Codable, Identifiable {
    let short: VowelForm
    let long: VowelForm
    let sounds: VowelSounds

    var id: String { sounds.en + (short.closed ?? "") + (short.open ?? "") }

    var sound: String { sounds.en }

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

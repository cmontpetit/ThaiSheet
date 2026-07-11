//
//  ToneMarkCard.swift
//  ThaiSheet
//

import Foundation

// Represents a single tone mark card using fixed consonants
// (ค for low, ก for mid, ข for high class)
struct ToneMarkCard: Identifiable {
    let toneMark: ToneMark
    let consonantClass: ConsonantClassType
    let display: String
    let correctTone: String

    var id: String { display }

    enum ConsonantClassType: String, CaseIterable {
        case low = "Low"
        case mid = "Mid"
        case high = "High"

        var label: String {
            String(localized: String.LocalizationValue(rawValue), bundle: .appLanguage)
        }
    }

    /// Creates 8 cards matching the reference: 2 low (ค่า ค้า) + 4 mid
    /// (ก่า ก้า ก๊า ก๋า) + 2 high (ข่า ข้า). Unmarked syllables have no
    /// cards — they follow the tone rules.
    static func allCards(from toneMarks: [ToneMark]) -> [ToneMarkCard] {
        var cards: [ToneMarkCard] = []

        for toneMark in toneMarks {
            for entry in toneMark.classEntries {
                guard let tone = entry.tone,
                      let classType = ConsonantClassType(rawValue: entry.className) else { continue }
                cards.append(ToneMarkCard(
                    toneMark: toneMark,
                    consonantClass: classType,
                    display: entry.soundKey,
                    correctTone: tone
                ))
            }
        }
        return cards.shuffled()
    }
}

//
//  ToneMarkCard.swift
//  ThaiSheet
//

import Foundation

// Represents a single tone mark card using fixed consonants (ค for low, ก for mid/high)
struct ToneMarkCard: Identifiable {
    let toneMark: ToneMark
    let consonantClass: ConsonantClassType
    let display: String
    let correctTone: String

    var id: String { display }

    enum ConsonantClassType: String, CaseIterable {
        case low = "Low"
        case midHigh = "Mid/High"
    }

    /// Creates 8 cards matching the reference: 3 for low class (ค) + 5 for mid/high class (ก)
    static func allCards(from toneMarks: [ToneMark]) -> [ToneMarkCard] {
        var cards: [ToneMarkCard] = []

        for toneMark in toneMarks {
            // Low class card (using ค)
            if toneMark.onLowConsonant != "n/a" {
                cards.append(ToneMarkCard(
                    toneMark: toneMark,
                    consonantClass: .low,
                    display: toneMark.soundKeyLow,
                    correctTone: toneMark.onLowConsonant
                ))
            }

            // Mid/High class card (using ก)
            if toneMark.onMidHighConsonant != "n/a" {
                cards.append(ToneMarkCard(
                    toneMark: toneMark,
                    consonantClass: .midHigh,
                    display: toneMark.soundKeyMidHigh,
                    correctTone: toneMark.onMidHighConsonant
                ))
            }
        }
        return cards.shuffled()
    }
}

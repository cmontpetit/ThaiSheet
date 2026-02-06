//
//  VowelCard.swift
//  ThaiSheet
//

import Foundation

// Represents a single vowel form card
struct VowelCard: Identifiable {
    let vowel: Vowel
    let duration: VowelDuration
    let form: VowelFormType
    let display: String
    let acceptsBothDurations: Bool  // True if this form appears in both short and long

    var id: String { display }

    enum VowelDuration: String, CaseIterable {
        case short = "Short"
        case long = "Long"
    }

    enum VowelFormType: String, CaseIterable {
        case closed = "Closed"
        case open = "Open"
    }

    /// Returns the alternative duration if this card accepts both, nil otherwise
    var alternativeDuration: VowelDuration? {
        guard acceptsBothDurations else { return nil }
        return duration == .short ? .long : .short
    }

    static func allCards(from vowels: [Vowel]) -> [VowelCard] {
        var cards: [VowelCard] = []
        var seenDisplays: Set<String> = []
        for vowel in vowels {
            if let form = vowel.short.closed, !seenDisplays.contains(form) {
                let isDuplicate = vowel.isDuplicate(form: form)
                cards.append(VowelCard(vowel: vowel, duration: .short, form: .closed, display: form, acceptsBothDurations: isDuplicate))
                seenDisplays.insert(form)
            }
            if let form = vowel.short.open, !seenDisplays.contains(form) {
                let isDuplicate = vowel.isDuplicate(form: form)
                cards.append(VowelCard(vowel: vowel, duration: .short, form: .open, display: form, acceptsBothDurations: isDuplicate))
                seenDisplays.insert(form)
            }
            if let form = vowel.long.closed, !seenDisplays.contains(form) {
                let isDuplicate = vowel.isDuplicate(form: form)
                cards.append(VowelCard(vowel: vowel, duration: .long, form: .closed, display: form, acceptsBothDurations: isDuplicate))
                seenDisplays.insert(form)
            }
            if let form = vowel.long.open, !seenDisplays.contains(form) {
                let isDuplicate = vowel.isDuplicate(form: form)
                cards.append(VowelCard(vowel: vowel, duration: .long, form: .open, display: form, acceptsBothDurations: isDuplicate))
                seenDisplays.insert(form)
            }
        }
        return cards
    }
}

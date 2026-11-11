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

    /// Durable progress key: the vowel row's stable id plus the structural
    /// variant this card represents (or the row's explicit key for that slot).
    /// Independent of `display`, so correcting a written form does not orphan
    /// a user's progress.
    var id: String { vowel.progressKey(for: duration, form: form) }

    /// Whether the card asks Short/Long. Skipped where length does not contrast.
    var asksDuration: Bool { vowel.hasLengthContrast }

    /// Whether the card asks Open/Closed. Skipped for vowel-plus-ending
    /// combinations, which take no further final consonant.
    var asksForm: Bool { !vowel.isCombination }

    var pronunciationWord: ReferenceSampleWord? {
        vowel.pronunciation(for: duration, form: form)
    }

    enum VowelDuration: String, CaseIterable {
        case short = "Short"
        case long = "Long"

        var label: String {
            switch self {
            case .short: return String(localized: "Short", bundle: .appLanguage)
            case .long: return String(localized: "Long", bundle: .appLanguage)
            }
        }
    }

    enum VowelFormType: String, CaseIterable {
        case closed = "Closed"
        case open = "Open"

        var label: String {
            switch self {
            case .closed: return String(localized: "Closed", bundle: .appLanguage)
            case .open: return String(localized: "Open", bundle: .appLanguage)
            }
        }
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
            let variants: [(form: String?, duration: VowelDuration, formType: VowelFormType)] = [
                (vowel.short.closed, .short, .closed),
                (vowel.short.open, .short, .open),
                (vowel.long.closed, .long, .closed),
                (vowel.long.open, .long, .open),
            ]
            for variant in variants {
                guard let form = variant.form, !seenDisplays.contains(form) else { continue }
                cards.append(VowelCard(
                    vowel: vowel,
                    duration: variant.duration,
                    form: variant.formType,
                    display: form,
                    acceptsBothDurations: vowel.isDuplicate(form: form)
                ))
                seenDisplays.insert(form)
            }
        }
        return cards
    }
}

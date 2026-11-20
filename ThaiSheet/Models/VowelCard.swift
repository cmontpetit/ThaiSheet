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

    /// For a form shared by both durations (เกิ-): the slot whose example the
    /// card presents, when it is not `duration`. Set by the chapter scope when
    /// only the other slot is in scope. Presentation only: the progress `id`
    /// and grading (both durations accepted) still follow `duration`.
    var presentedDuration: VowelDuration? = nil

    /// The duration whose example, audio, details, and note the card shows.
    var shownDuration: VowelDuration { presentedDuration ?? duration }

    /// This card presenting its other duration's slot. Only meaningful for a
    /// card that accepts both durations.
    func presenting(_ duration: VowelDuration) -> VowelCard {
        var card = self
        card.presentedDuration = duration == self.duration ? nil : duration
        return card
    }

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

    /// The sound of the form the card shows ("a", not the row's "a/aa").
    /// Display only: the Sound question's options and grading use the row label.
    var shownSound: String { vowel.sound(for: shownDuration, form: display) }

    var pronunciationWord: ReferenceSampleWord? {
        vowel.pronunciation(for: shownDuration, form: form)
    }

    var prompt: String {
        pronunciationWord?.word ?? ThaiDisplay.placeholder(display.replacingOccurrences(of: "-", with: ""))
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
        return shownDuration == .short ? .long : .short
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

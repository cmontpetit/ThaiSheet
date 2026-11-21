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

    /// The card also stands for its duration's closed slot, because the closed
    /// spelling is the open one plus the final-consonant dash (◌า / ◌า-). The
    /// card is keyed on its open slot and its Form answer is Both.
    var coversClosedForm: Bool = false

    /// The bare vowel would look like another card's (ฤ reads "rue" or "ri"),
    /// so the card prompts with its pronunciation word instead.
    var promptsWithWord: Bool = false

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

    /// Whether the card asks Open/Closed/Both. Skipped for vowel-plus-ending
    /// combinations, which take no further final consonant.
    var asksForm: Bool { !vowel.isCombination }

    /// The sound of the form the card shows ("a", not the row's "a/aa").
    /// Display only: the Sound question's options and grading use the row label.
    var shownSound: String { vowel.sound(for: shownDuration, form: display) }

    var pronunciationWord: ReferenceSampleWord? {
        vowel.pronunciation(for: shownDuration, form: form)
    }

    /// The written vowel without the final-consonant dash, ready to display.
    var bareForm: String {
        ThaiDisplay.placeholder(display.replacingOccurrences(of: "-", with: ""))
    }

    /// The card face: the bare vowel, or the pronunciation word where the bare
    /// vowel is ambiguous. A word would give the Form answer away (การ shows
    /// its final ร), so it is otherwise only revealed with the answer.
    var prompt: String {
        guard promptsWithWord, let word = pronunciationWord?.word else { return bareForm }
        return word
    }

    /// The Form answer: where this spelling is used.
    var formAnswer: FormAnswer {
        if coversClosedForm { return .both }
        return form == .open ? .open : .closed
    }

    /// One example word per slot the card covers, shown after reveal.
    var revealedSamples: [RevealedSample] {
        let slots: [VowelFormType] = coversClosedForm ? [.open, .closed] : [form]
        return slots.compactMap { slot in
            vowel.pronunciation(for: shownDuration, form: slot).map { RevealedSample(form: slot, word: $0) }
        }
    }

    /// The notes for every slot the card covers, without repeats.
    var notes: [String] {
        let slots: [VowelFormType] = coversClosedForm ? [.open, .closed] : [form]
        var seen: [String] = []
        for slot in slots {
            if let note = vowel.note(for: shownDuration.rawValue, form: slot.rawValue), !seen.contains(note) {
                seen.append(note)
            }
        }
        return seen
    }

    struct RevealedSample: Identifiable {
        let form: VowelFormType
        let word: ReferenceSampleWord
        var id: VowelFormType { form }
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

    /// The Form question's answers. Distinct from `VowelFormType`, which names
    /// a storage slot: Both is an answer, never a slot.
    enum FormAnswer: String, CaseIterable {
        case open = "Open"
        case closed = "Closed"
        case both = "Both"

        var label: String {
            switch self {
            case .open: return String(localized: "Open", bundle: .appLanguage)
            case .closed: return String(localized: "Closed", bundle: .appLanguage)
            case .both: return String(localized: "Both", bundle: .appLanguage)
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
                // A closed spelling that is the open one plus the dash merges
                // into one card keyed on the open slot, wherever it comes first.
                let slots = variant.duration == .short ? vowel.short : vowel.long
                let merged = sharesSpelling(open: slots.open, closed: slots.closed)
                    && !vowel.isCombination
                let display = merged ? slots.open! : form
                let formType: VowelFormType = merged ? .open : variant.formType
                cards.append(VowelCard(
                    vowel: vowel,
                    duration: variant.duration,
                    form: formType,
                    display: display,
                    acceptsBothDurations: vowel.isDuplicate(form: display),
                    coversClosedForm: merged
                ))
                seenDisplays.insert(form)
                if merged {
                    seenDisplays.insert(slots.open!)
                    seenDisplays.insert(slots.closed!)
                }
            }
        }

        // Cards whose bare vowels look alike prompt with their words instead.
        let bareCounts = Dictionary(grouping: cards, by: \.bareForm).mapValues(\.count)
        for index in cards.indices where bareCounts[cards[index].bareForm, default: 0] > 1 {
            cards[index].promptsWithWord = true
        }
        return cards
    }

    /// Whether this card stands for a written form from the Reference table:
    /// its own, or the closed spelling it merged ("กา-" for ◌า).
    func covers(form written: String) -> Bool {
        written == display || (coversClosedForm && Self.sharesSpelling(open: display, closed: written))
    }

    /// Whether a closed spelling differs from the open one only by the dash.
    static func sharesSpelling(open: String?, closed: String?) -> Bool {
        guard let open, let closed, open != closed else { return false }
        return closed.replacingOccurrences(of: "-", with: "") == open
    }
}

//
//  ToneDerivation.swift
//  ThaiSheet
//

import Foundation

/// Why a syllable is read with its tone: the tone plus the ordered lookups
/// that produced it, derived from the bundled tone tables.
///
/// The caller states the facts the tables key on. Nothing here reads Thai
/// text: classifying a written syllable (unwritten vowels, leading ห/อ,
/// irregular words) is a separate problem. The tables are the only source of
/// tones, so an input they do not cover yields `.notCovered`, never a guess.
struct ToneDerivation {

    struct Input: Hashable {
        /// The class that governs the tone (for หน-, อย- and similar, the
        /// class of the leading letter: the caller resolves that).
        let consonantClass: ConsonantClass
        let vowelDuration: VowelCard.VowelDuration
        let ending: Ending
        /// A mark from the tone-marks table, or nil for an unmarked syllable
        let toneMark: String?

        init(
            consonantClass: ConsonantClass,
            vowelDuration: VowelCard.VowelDuration,
            ending: Ending,
            toneMark: String? = nil
        ) {
            self.consonantClass = consonantClass
            self.vowelDuration = vowelDuration
            self.ending = ending
            self.toneMark = toneMark
        }
    }

    /// How the syllable ends, in the tone-rules table's terms. Raw values
    /// are the table's own tokens.
    enum Ending: String, CaseIterable {
        /// Sonorant final, or a long vowel with no final
        case live = "Live"
        /// Stop final, or a short vowel with no final (the table's "Dead"
        /// and "Dead/None")
        case dead = "Dead"
    }

    /// One lookup. Only facts that narrowed the result appear: a marked
    /// syllable has no ending or duration step, and an unmarked one has a
    /// duration step only when its rule depends on vowel length.
    enum Step {
        /// No tone mark: the tone-rules table applies
        case noToneMark
        /// A tone mark is present: the tone-marks table applies
        case toneMark(String)
        case consonantClass(ConsonantClass)
        case ending(Ending)
        case vowelDuration(VowelCard.VowelDuration)
        /// Deciding step for an unmarked syllable: the matching rule row
        case toneRule(ToneRule)
        /// Deciding step for a marked syllable: the mark's row, read in the
        /// column of the consonant class
        case toneMarkRow(ToneMark, ConsonantClass)

        var isDeciding: Bool {
            switch self {
            case .toneRule, .toneMarkRow: return true
            default: return false
            }
        }
    }

    enum NotCovered: Equatable {
        /// The mark is not a row of the tone-marks table
        case unknownToneMark
        /// The mark's row has no tone for this class (๊/๋ are mid-class only)
        case markNotUsedWithClass
        /// No tone rule matches the input
        case noMatchingRule
        /// More than one tone rule matches: a data error
        case ambiguousRules
    }

    enum Outcome: Equatable {
        /// The tone as the tables spell it ("Low", "Mid", "High", "Falling", "Rising")
        case tone(String)
        case notCovered(NotCovered)
    }

    let input: Input
    /// The lookups in the order a reader makes them. When the outcome is a
    /// tone the last step is the deciding one, otherwise the steps stop
    /// where the tables ran out.
    let steps: [Step]
    let outcome: Outcome

    var tone: String? {
        if case .tone(let tone) = outcome { return tone }
        return nil
    }

    var decidingStep: Step? {
        steps.last.flatMap { $0.isDeciding ? $0 : nil }
    }

    // MARK: - Derivation

    static func derive(_ input: Input, rules: [ToneRule], marks: [ToneMark]) -> ToneDerivation {
        if let mark = input.toneMark {
            return deriveMarked(input, mark: mark, marks: marks)
        }
        return deriveUnmarked(input, rules: rules)
    }

    /// A tone mark overrides the tone rules. The tone-marks table has no
    /// duration or ending dimension, so neither is consulted.
    private static func deriveMarked(_ input: Input, mark: String, marks: [ToneMark]) -> ToneDerivation {
        var steps: [Step] = [.toneMark(mark)]
        guard let row = marks.first(where: { $0.mark == mark }) else {
            return ToneDerivation(input: input, steps: steps, outcome: .notCovered(.unknownToneMark))
        }
        steps.append(.consonantClass(input.consonantClass))
        guard let tone = row.tone(on: input.consonantClass) else {
            return ToneDerivation(input: input, steps: steps, outcome: .notCovered(.markNotUsedWithClass))
        }
        steps.append(.toneMarkRow(row, input.consonantClass))
        return ToneDerivation(input: input, steps: steps, outcome: .tone(tone))
    }

    private static func deriveUnmarked(_ input: Input, rules: [ToneRule]) -> ToneDerivation {
        var steps: [Step] = [.noToneMark, .consonantClass(input.consonantClass), .ending(input.ending)]
        let matches = rules.filter { $0.matches(input) }
        guard let rule = matches.first else {
            return ToneDerivation(input: input, steps: steps, outcome: .notCovered(.noMatchingRule))
        }
        guard matches.count == 1 else {
            return ToneDerivation(input: input, steps: steps, outcome: .notCovered(.ambiguousRules))
        }
        if rule.dependsOnVowelDuration {
            steps.append(.vowelDuration(input.vowelDuration))
        }
        steps.append(.toneRule(rule))
        return ToneDerivation(input: input, steps: steps, outcome: .tone(rule.tone))
    }
}

// MARK: - Reading the tables

private extension ToneRule {
    /// The table's wildcard for "either vowel length"
    static let anyDuration = "Any"

    var dependsOnVowelDuration: Bool { vowelDuration != Self.anyDuration }

    func matches(_ input: ToneDerivation.Input) -> Bool {
        guard ConsonantClass(rawValue: initialConsonant.lowercased()) == input.consonantClass else {
            return false
        }
        guard !dependsOnVowelDuration || vowelDuration == input.vowelDuration.rawValue else {
            return false
        }
        // `end` is "Live", "Dead", or "Dead/None" (a short vowel with no
        // final is a dead syllable). An unrecognized token matches nothing.
        return end.split(separator: "/").contains { $0 == input.ending.rawValue }
    }
}

private extension ToneMark {
    func tone(on consonantClass: ConsonantClass) -> String? {
        switch consonantClass {
        case .low: return onLow
        case .mid: return onMid
        case .high: return onHigh
        }
    }
}

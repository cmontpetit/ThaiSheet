//
//  ToneFinder.swift
//  ThaiSheet
//

import Foundation

/// State of the "Why this tone?" sheet: one typed or pasted syllable, plus
/// the facts the learner sets by hand. A hand-set fact wins over what was
/// read from the text, and editing the text discards the hand-set facts.
///
/// Session-only: nothing here is persisted.
struct ToneFinder {

    enum MarkChoice: Hashable {
        case none
        case mark(String)
    }

    var text = "" {
        didSet {
            guard text != oldValue else { return }
            chosenClass = nil
            chosenMark = nil
            chosenEnding = nil
            chosenDuration = nil
        }
    }

    var chosenClass: ConsonantClass?
    var chosenMark: MarkChoice?
    var chosenEnding: ToneDerivation.Ending?
    var chosenDuration: VowelCard.VowelDuration?

    enum ResultNotice: Equatable {
        /// The tone depends on the vowel length, which is not known
        case chooseVowelLength
        case markNotUsedWithClass
        case noRule
    }

    struct Resolution {
        /// The most likely reading of the text, when it reads as one syllable
        let reading: SyllableParser.Reading?
        /// The text is not empty and does not read as one syllable
        let textNotRead: Bool

        // The facts in effect: hand-set, else read from the text. Nil means
        // unknown (not read, or the readings of the spelling differ).
        let consonantClass: ConsonantClass?
        let mark: MarkChoice?
        let ending: ToneDerivation.Ending?
        let duration: VowelCard.VowelDuration?

        /// Set only when the facts give a tone
        let derivation: ToneDerivation?
        let notice: ResultNotice?

        /// Whether the ending and vowel length play a part. A tone mark
        /// decides with the consonant class alone.
        var usesEndingAndDuration: Bool {
            if case .mark = mark { return false }
            return true
        }
    }

    func resolve(parser: SyllableParser, rules: [ToneRule], marks: [ToneMark]) -> Resolution {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var readings: [SyllableParser.Reading] = []
        var textNotRead = false
        if !trimmed.isEmpty {
            switch parser.parse(trimmed) {
            case .readings(let found): readings = found
            case .notCovered: textNotRead = true
            }
        }

        /// A fact every reading of the spelling agrees on
        func shared<Value: Equatable>(_ fact: KeyPath<SyllableParser.Reading, Value>) -> Value? {
            guard let first = readings.first?[keyPath: fact] else { return nil }
            return readings.allSatisfy { $0[keyPath: fact] == first } ? first : nil
        }

        let readMark = readings.first.map { $0.toneMark.map(MarkChoice.mark) ?? .none }
        let consonantClass = chosenClass ?? shared(\.consonantClass)
        // With no text the sheet starts on "no mark". Text that could not
        // be read leaves the mark unset: it may well carry one.
        let mark = chosenMark ?? readMark ?? (trimmed.isEmpty ? MarkChoice.none : nil)
        let ending = chosenEnding ?? shared(\.ending)
        let duration = chosenDuration ?? shared(\.vowelDuration)

        var derivation: ToneDerivation?
        var notice: ResultNotice?

        func derive(
            _ consonantClass: ConsonantClass,
            _ duration: VowelCard.VowelDuration,
            _ ending: ToneDerivation.Ending,
            _ toneMark: String?
        ) -> ToneDerivation {
            ToneDerivation.derive(
                ToneDerivation.Input(
                    consonantClass: consonantClass,
                    vowelDuration: duration,
                    ending: ending,
                    toneMark: toneMark
                ),
                rules: rules,
                marks: marks
            )
        }

        var candidate: ToneDerivation?
        if let consonantClass, let mark {
            switch mark {
            case .mark(let toneMark):
                // Ending and duration are not consulted for a marked syllable
                candidate = derive(consonantClass, duration ?? .long, ending ?? .live, toneMark)
            case .none:
                if let ending {
                    // An unknown length is fine when both lengths agree
                    let durations = duration.map { [$0] } ?? VowelCard.VowelDuration.allCases
                    let derivations = durations.map { derive(consonantClass, $0, ending, nil) }
                    if derivations.allSatisfy({ $0.outcome == derivations[0].outcome }) {
                        candidate = derivations[0]
                    } else {
                        notice = .chooseVowelLength
                    }
                }
            }
        }

        if let candidate {
            switch candidate.outcome {
            case .tone: derivation = candidate
            case .notCovered(.markNotUsedWithClass): notice = .markNotUsedWithClass
            case .notCovered: notice = .noRule
            }
        }

        return Resolution(
            reading: readings.first,
            textNotRead: textNotRead,
            consonantClass: consonantClass,
            mark: mark,
            ending: ending,
            duration: duration,
            derivation: derivation,
            notice: notice
        )
    }
}

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

    /// One plain-language statement about how the text was read, so the
    /// learner can check the reading before trusting the tone. Built from
    /// the text only: facts set by hand do not change it.
    enum ReadingNote: Equatable {
        /// The readings of the spelling start differently (ควบ: ค or คว)
        case otherReading
        case consonantClass(letter: String, ConsonantClass)
        /// Leading ห: silent, and puts the following letter in the high class
        case silentHo(following: String)
        /// Both letters pronounced; the first sets the class
        case cluster(letters: String, classLetter: String)
        /// Read as one sound (ทร, สร, จร); the first letter sets the class
        case irregularCluster(letters: String, classLetter: String)
        case toneMark(String)
        case unwrittenVowel
        /// A vowel-plus-ending row (◌าย, ไ◌): live, takes no final
        case vowelWithEnding(form: String)
        case vowelLength(form: String, VowelCard.VowelDuration)
        /// The spelling is the same short and long (เ◌ิ-)
        case vowelLengthNotShown(form: String)
        case finalConsonant(letters: String, sound: String, ToneDerivation.Ending)
        /// Open syllable: the vowel length decides live or dead
        case noFinal(VowelCard.VowelDuration)
        case silenced(letters: String)
    }

    struct Resolution {
        /// The most likely reading of the text, when it reads as one syllable
        let reading: SyllableParser.Reading?
        /// How the text was read, in reading order. Empty when it was not read.
        let readingNotes: [ReadingNote]
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
            readingNotes: Self.notes(for: readings),
            textNotRead: textNotRead,
            consonantClass: consonantClass,
            mark: mark,
            ending: ending,
            duration: duration,
            derivation: derivation,
            notice: notice
        )
    }

    /// Notes for the first (most likely) reading. A fact the readings do
    /// not agree on is described as unknown, never taken from one reading.
    static func notes(for readings: [SyllableParser.Reading]) -> [ReadingNote] {
        guard let reading = readings.first else { return [] }
        var notes: [ReadingNote] = []

        if readings.contains(where: { $0.initial != reading.initial }) {
            notes.append(.otherReading)
        }

        let classLetter = String(reading.initial.prefix(1))
        switch reading.initialCluster?.type {
        case .silent?:
            notes.append(.silentHo(following: String(reading.initial.dropFirst())))
        case .smooth?:
            notes.append(.cluster(letters: reading.initial, classLetter: classLetter))
            notes.append(.consonantClass(letter: classLetter, reading.consonantClass))
        case .irregular?:
            notes.append(.irregularCluster(letters: reading.initial, classLetter: classLetter))
            notes.append(.consonantClass(letter: classLetter, reading.consonantClass))
        case nil:
            notes.append(.consonantClass(letter: reading.initial, reading.consonantClass))
        }

        if let mark = reading.toneMark {
            notes.append(.toneMark(mark))
        }

        let lengthIsShown = readings.allSatisfy { $0.vowelDuration == reading.vowelDuration }
        if !reading.isVowelWritten {
            notes.append(.unwrittenVowel)
        } else if reading.vowel.isCombination {
            notes.append(.vowelWithEnding(form: reading.form))
        } else if reading.toneMark == nil {
            // With a tone mark the written length can mislead (◌็ is not
            // written: เล่น), and the mark decides the tone without it
            notes.append(lengthIsShown
                ? .vowelLength(form: reading.form, reading.vowelDuration)
                : .vowelLengthNotShown(form: reading.form))
        }

        if reading.toneMark == nil {
            if let final = reading.final, let sound = reading.finalSound {
                notes.append(.finalConsonant(letters: final, sound: sound, reading.ending))
            } else if reading.final == nil, !reading.vowel.isCombination, lengthIsShown {
                notes.append(.noFinal(reading.vowelDuration))
            }
        }

        if let silenced = reading.silenced {
            notes.append(.silenced(letters: silenced))
        }
        return notes
    }
}

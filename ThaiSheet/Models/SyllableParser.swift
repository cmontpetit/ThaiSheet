//
//  SyllableParser.swift
//  ThaiSheet
//

import Foundation

/// Reads ONE written Thai syllable into the facts the tone tables key on.
///
/// Strict by design: the text must match a written vowel form from
/// `vowels.json` around a consonant or a cluster from `clusters.json`.
/// Anything else is `.notCovered`, never a best guess. It does not split
/// words into syllables.
///
/// Three facts the data files do not hold are stated here as code:
/// which final sounds are live or dead, that an open short vowel is dead and
/// an open long vowel is live, and that vowel-plus-ending rows are live.
/// A cluster takes the class of its first letter (this is how leading ห
/// raises the class).
struct SyllableParser {

    /// One way to read the text. Several readings can fit one spelling
    /// (กาย is ◌าย, and also ◌า plus a final ย).
    struct Reading {
        /// The initial consonant or cluster as written ("น", "หน", "กร")
        let initial: String
        /// The class that governs the tone: the class of the first letter
        let consonantClass: ConsonantClass
        let vowel: Vowel
        /// The written length. With a tone mark, ◌็ is not written (เล่น),
        /// so a short vowel can read as long here: a marked syllable's tone
        /// does not depend on length.
        let vowelDuration: VowelCard.VowelDuration
        /// The final consonant or final cluster as written, if any
        let final: String?
        let ending: ToneDerivation.Ending
        let toneMark: String?

        var toneInput: ToneDerivation.Input {
            ToneDerivation.Input(
                consonantClass: consonantClass,
                vowelDuration: vowelDuration,
                ending: ending,
                toneMark: toneMark
            )
        }
    }

    enum NotCovered: Equatable {
        case empty
        /// Contains something other than Thai letters and marks
        case notThaiScript
        case severalToneMarks
        /// Fits no written vowel form: more than one syllable, an unwritten
        /// vowel between syllables, a spelling the data does not list
        case noKnownPattern
        /// The spelling has readings that give different tones (เลิก: the
        /// written form does not show the vowel length)
        case readingsDisagree
    }

    enum Outcome {
        /// Never empty
        case readings([Reading])
        case notCovered(NotCovered)
    }

    /// The tone of a pasted syllable, when every reading agrees on it
    enum ToneOutcome {
        /// `ToneDerivation.outcome` can still be `.notCovered` (a mid-only
        /// mark on another class)
        case derived(Reading, ToneDerivation)
        case notCovered(NotCovered)
    }

    // MARK: - Tables

    /// Final sounds that close a syllable dead (stops) or live (sonorants).
    /// Keyed on `Consonant.finalSound`; not present in the data files.
    private static let deadFinalSounds: Set<String> = ["-k", "-t", "-p"]
    private static let liveFinalSounds: Set<String> = ["-n", "-m", "-ng", "-y", "-w"]

    private static let placeholder: Unicode.Scalar = "ก"
    private static let finalSlot: Unicode.Scalar = "-"
    /// ◌์ silences the letter it sits on
    private static let thanthakhat: Unicode.Scalar = "\u{0E4C}"
    /// Vowel marks that can be silenced together with their consonant (ธิ์, ธุ์)
    private static let silencedVowelMarks: Set<Unicode.Scalar> = ["\u{0E34}", "\u{0E38}"]
    private static let thaiLettersAndMarks: ClosedRange<UInt32> = 0x0E01...0x0E4E

    /// A written vowel form split around its consonant placeholder
    private struct Template {
        let vowel: Vowel
        let duration: VowelCard.VowelDuration
        /// Letters written before the initial (เ, แ, โ, ไ, ใ)
        let prefix: [Unicode.Scalar]
        /// Letters and marks written after the initial
        let rime: [Unicode.Scalar]
        let takesFinal: Bool
    }

    private let templates: [Template]
    private let consonants: [Unicode.Scalar: Consonant]
    private let initialClusters: Set<String>
    /// Final cluster letters → final sound ("ทร" → "-t")
    private let finalClusterSounds: [String: String]
    private let toneMarks: Set<Unicode.Scalar>

    init(consonants: [Consonant], vowels: [Vowel], clusters: [Cluster], toneMarks: [ToneMark]) {
        var byScalar: [Unicode.Scalar: Consonant] = [:]
        for consonant in consonants {
            let scalars = Array(consonant.character.unicodeScalars)
            if scalars.count == 1 { byScalar[scalars[0]] = consonant }
        }
        self.consonants = byScalar

        var initials: Set<String> = []
        var finals: [String: String] = [:]
        for cluster in clusters {
            let letters = cluster.cluster.replacingOccurrences(of: "-", with: "")
            if cluster.cluster.hasSuffix("-") {
                initials.insert(letters)
            } else if cluster.cluster.hasPrefix("-"), let sound = cluster.sound {
                finals[letters] = sound
            }
        }
        self.initialClusters = initials
        self.finalClusterSounds = finals

        self.toneMarks = Set(toneMarks.flatMap { Array($0.mark.unicodeScalars) })

        var templates: [Template] = []
        for vowel in vowels {
            let slots: [(VowelCard.VowelDuration, String?)] = [
                (.short, vowel.short.closed), (.short, vowel.short.open),
                (.long, vowel.long.closed), (.long, vowel.long.open),
            ]
            for (duration, form) in slots {
                guard let form else { continue }
                let scalars = Array(form.unicodeScalars)
                // ฤ and ฦ are written without a consonant: not covered
                guard let slot = scalars.firstIndex(of: Self.placeholder) else { continue }
                var rime = Array(scalars[(slot + 1)...])
                let takesFinal = rime.last == Self.finalSlot
                if takesFinal { rime.removeLast() }
                templates.append(Template(
                    vowel: vowel,
                    duration: duration,
                    prefix: Array(scalars[..<slot]),
                    rime: rime,
                    takesFinal: takesFinal
                ))
            }
        }
        self.templates = templates
    }

    // MARK: - Parsing

    func parse(_ text: String) -> Outcome {
        var scalars = Array(text.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars)
        guard !scalars.isEmpty else { return .notCovered(.empty) }
        guard scalars.allSatisfy({ Self.thaiLettersAndMarks.contains($0.value) }) else {
            return .notCovered(.notThaiScript)
        }

        // A silenced last letter (สัตว์, สิทธิ์) is not part of the reading
        if let killer = scalars.firstIndex(of: Self.thanthakhat) {
            guard killer == scalars.count - 1 else { return .notCovered(.noKnownPattern) }
            scalars.removeLast()
            if let mark = scalars.last, Self.silencedVowelMarks.contains(mark) { scalars.removeLast() }
            guard let silenced = scalars.popLast(), consonants[silenced] != nil else {
                return .notCovered(.noKnownPattern)
            }
        }

        let markIndices = scalars.indices.filter { toneMarks.contains(scalars[$0]) }
        guard markIndices.count <= 1 else { return .notCovered(.severalToneMarks) }
        let markIndex = markIndices.first
        let mark = markIndex.map { String(scalars[$0]) }
        if let markIndex { scalars.remove(at: markIndex) }

        let found = readings(of: scalars, markIndex: markIndex, mark: mark)
        guard !found.isEmpty else { return .notCovered(.noKnownPattern) }
        // A dedicated vowel-plus-ending row describes the spelling better
        // than a basic vowel plus a ย/ว final
        return .readings(found.filter { $0.vowel.isCombination } + found.filter { !$0.vowel.isCombination })
    }

    /// The tone of one written syllable. Refuses when the readings of the
    /// spelling do not all derive the same result.
    func tone(of text: String, rules: [ToneRule], marks: [ToneMark]) -> ToneOutcome {
        switch parse(text) {
        case .notCovered(let reason):
            return .notCovered(reason)
        case .readings(let readings):
            let derivations = readings.map { ToneDerivation.derive($0.toneInput, rules: rules, marks: marks) }
            guard derivations.allSatisfy({ $0.outcome == derivations[0].outcome }) else {
                return .notCovered(.readingsDisagree)
            }
            return .derived(readings[0], derivations[0])
        }
    }

    /// - Parameters:
    ///   - scalars: the syllable without its tone mark
    ///   - markIndex: where the tone mark sat, counted in the original text
    private func readings(of scalars: [Unicode.Scalar], markIndex: Int?, mark: String?) -> [Reading] {
        var result: [Reading] = []
        for template in templates {
            let initialStart = template.prefix.count
            guard scalars.count > initialStart, Array(scalars[..<initialStart]) == template.prefix else {
                continue
            }
            for initialLength in 1...2 {
                let rimeStart = initialStart + initialLength
                let rimeEnd = rimeStart + template.rime.count
                guard rimeEnd <= scalars.count else { continue }

                let initial = Array(scalars[initialStart..<rimeStart])
                guard let first = consonants[initial[0]] else { continue }
                if initialLength == 2, !initialClusters.contains(Self.string(initial)) { continue }
                guard Array(scalars[rimeStart..<rimeEnd]) == template.rime else { continue }

                let rest = Array(scalars[rimeEnd...])
                let ending: ToneDerivation.Ending
                if template.takesFinal {
                    guard let closed = self.ending(ofFinal: rest) else { continue }
                    ending = closed
                } else {
                    guard rest.isEmpty else { continue }
                    let live = template.vowel.isCombination || template.duration == .long
                    ending = live ? .live : .dead
                }

                // The tone mark sits on the last initial consonant, after
                // an above/below vowel mark when there is one
                if let markIndex {
                    let overVowelMark = template.rime.first?.properties.generalCategory == .nonspacingMark
                    guard markIndex == rimeStart + (overVowelMark ? 1 : 0) else { continue }
                }

                result.append(Reading(
                    initial: Self.string(initial),
                    consonantClass: first.consonantClass,
                    vowel: template.vowel,
                    vowelDuration: template.duration,
                    final: rest.isEmpty ? nil : Self.string(rest),
                    ending: ending,
                    toneMark: mark
                ))
            }
        }
        return result
    }

    private func ending(ofFinal letters: [Unicode.Scalar]) -> ToneDerivation.Ending? {
        let sound: String?
        switch letters.count {
        case 1: sound = consonants[letters[0]]?.finalSound
        case 2: sound = finalClusterSounds[Self.string(letters)]
        default: sound = nil
        }
        guard let sound else { return nil }
        if Self.deadFinalSounds.contains(sound) { return .dead }
        if Self.liveFinalSounds.contains(sound) { return .live }
        return nil
    }

    private static func string(_ scalars: [Unicode.Scalar]) -> String {
        String(String.UnicodeScalarView(scalars))
    }
}

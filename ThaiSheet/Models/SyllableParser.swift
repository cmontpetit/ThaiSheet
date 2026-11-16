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
        /// The row of `clusters.json` when the initial is two letters
        let initialCluster: Cluster?
        /// The class that governs the tone: the class of the first letter
        let consonantClass: ConsonantClass
        let vowel: Vowel
        /// The vowel's written form as the data stores it ("กา-", "เกา")
        let form: String
        /// False for the unwritten vowel (กลม: no vowel letter, o is read)
        let isVowelWritten: Bool
        /// The written length. With a tone mark, ◌็ is not written (เล่น),
        /// so a short vowel can read as long here: a marked syllable's tone
        /// does not depend on length.
        let vowelDuration: VowelCard.VowelDuration
        /// The final consonant or final cluster as written, if any
        let final: String?
        /// The final's sound as the data states it ("-k"), if any
        let finalSound: String?
        let ending: ToneDerivation.Ending
        let toneMark: String?
        /// Letters cancelled by ◌์ at the end, without the ◌์ (ว in สัตว์)
        let silenced: String?

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
    /// A consonant followed by ร with no written vowel is the long ◌อ vowel
    /// (พร = phaawn), and รร is its own vowel (สรร = sǎn). No vowel form in
    /// the data lists these spellings.
    private static let unwrittenVowelSpoiler: Unicode.Scalar = "ร"
    /// ◌์ silences the letter it sits on
    private static let thanthakhat: Unicode.Scalar = "\u{0E4C}"
    /// Vowel marks that can be silenced together with their consonant (ธิ์, ธุ์)
    private static let silencedVowelMarks: Set<Unicode.Scalar> = ["\u{0E34}", "\u{0E38}"]
    private static let thaiLettersAndMarks: ClosedRange<UInt32> = 0x0E01...0x0E4E

    /// A written vowel form split around its consonant placeholder
    private struct Template {
        let vowel: Vowel
        let form: String
        let duration: VowelCard.VowelDuration
        /// Letters written before the initial (เ, แ, โ, ไ, ใ)
        let prefix: [Unicode.Scalar]
        /// Letters and marks written after the initial
        let rime: [Unicode.Scalar]
        let takesFinal: Bool
    }

    private let templates: [Template]
    private let consonants: [Unicode.Scalar: Consonant]
    /// Initial cluster letters → row ("หน" → the silent ห row)
    private let initialClusters: [String: Cluster]
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

        var initials: [String: Cluster] = [:]
        var finals: [String: String] = [:]
        for cluster in clusters {
            let letters = cluster.cluster.replacingOccurrences(of: "-", with: "")
            if cluster.cluster.hasSuffix("-") {
                initials[letters] = cluster
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
                    form: form,
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
        var silenced: String?
        if let killer = scalars.firstIndex(of: Self.thanthakhat) {
            guard killer == scalars.count - 1 else { return .notCovered(.noKnownPattern) }
            scalars.removeLast()
            var cancelled: [Unicode.Scalar] = []
            if let mark = scalars.last, Self.silencedVowelMarks.contains(mark) {
                cancelled.append(scalars.removeLast())
            }
            guard let letter = scalars.popLast(), consonants[letter] != nil else {
                return .notCovered(.noKnownPattern)
            }
            cancelled.insert(letter, at: 0)
            silenced = Self.string(cancelled)
        }

        let markIndices = scalars.indices.filter { toneMarks.contains(scalars[$0]) }
        guard markIndices.count <= 1 else { return .notCovered(.severalToneMarks) }
        let markIndex = markIndices.first
        let mark = markIndex.map { String(scalars[$0]) }
        if let markIndex { scalars.remove(at: markIndex) }

        let found = readings(of: scalars, markIndex: markIndex, mark: mark, silenced: silenced)
        guard !found.isEmpty else { return .notCovered(.noKnownPattern) }
        // Ties keep the data order
        let ordered = found.enumerated().sorted {
            ($0.element.rank, $0.offset) < ($1.element.rank, $1.offset)
        }
        return .readings(ordered.map(\.element.reading))
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
    private func readings(
        of scalars: [Unicode.Scalar],
        markIndex: Int?,
        mark: String?,
        silenced: String?
    ) -> [(reading: Reading, rank: Int)] {
        var result: [(reading: Reading, rank: Int)] = []
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
                let cluster = initialLength == 2 ? initialClusters[Self.string(initial)] : nil
                if initialLength == 2, cluster == nil { continue }
                guard Array(scalars[rimeStart..<rimeEnd]) == template.rime else { continue }

                let rest = Array(scalars[rimeEnd...])
                // Read as the unwritten short vowel, พร would state the wrong
                // vowel and length. Not a reading: the spelling is refused
                // unless a written vowel form fits it (ควร = ค + ◌ว◌ + ร).
                // Only the form with no written vowel at all: เณร is เ◌ + ร.
                let isUnwrittenVowel = template.prefix.isEmpty && template.rime.isEmpty
                if isUnwrittenVowel, rest == [Self.unwrittenVowelSpoiler] { continue }
                let ending: ToneDerivation.Ending
                var finalSound: String?
                if template.takesFinal {
                    guard let sound = self.finalSound(of: rest), let closed = Self.ending(forFinalSound: sound) else {
                        continue
                    }
                    finalSound = sound
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

                // Most likely reading first: a dedicated vowel-plus-ending
                // row (◌าย) before a basic vowel plus a ย/ว final, and a
                // written vowel (สวน = ส + ◌ว◌ + น) before an unwritten one.
                let rank = template.vowel.isCombination ? 0 : (isUnwrittenVowel ? 2 : 1)
                result.append((
                    Reading(
                        initial: Self.string(initial),
                        initialCluster: cluster,
                        consonantClass: first.consonantClass,
                        vowel: template.vowel,
                        form: template.form,
                        isVowelWritten: !isUnwrittenVowel,
                        vowelDuration: template.duration,
                        final: rest.isEmpty ? nil : Self.string(rest),
                        finalSound: finalSound,
                        ending: ending,
                        toneMark: mark,
                        silenced: silenced
                    ),
                    rank
                ))
            }
        }
        return result
    }

    private func finalSound(of letters: [Unicode.Scalar]) -> String? {
        switch letters.count {
        case 1: return consonants[letters[0]]?.finalSound
        case 2: return finalClusterSounds[Self.string(letters)]
        default: return nil
        }
    }

    private static func ending(forFinalSound sound: String) -> ToneDerivation.Ending? {
        if deadFinalSounds.contains(sound) { return .dead }
        if liveFinalSounds.contains(sound) { return .live }
        return nil
    }

    private static func string(_ scalars: [Unicode.Scalar]) -> String {
        String(String.UnicodeScalarView(scalars))
    }
}

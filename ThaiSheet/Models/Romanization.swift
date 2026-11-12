//
//  Romanization.swift
//  ThaiSheet
//

import Foundation
import Observation

/// How romanized readings are displayed.
///
/// The data files always store ThaiSheet's own learner transcription. It is
/// regular enough to be parsed back into syllables (onset, vowel, glide, final,
/// tone), so the other schemes are rendered from it and never hand-written.
/// Quiz grading, search keys, and progress IDs keep using the stored strings;
/// only what is shown changes.
enum RomanizationScheme: String, CaseIterable, Identifiable {
    /// ThaiSheet's learner transcription (g/dt/bp, doubled long vowels, tone diacritics)
    case learner
    /// International Phonetic Alphabet, with tone diacritics
    case ipa
    /// Royal Thai General System: the official scheme. No tones, no vowel length.
    case rtgs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .learner: return String(localized: "ThaiSheet (learner)", bundle: .appLanguage)
        case .ipa: return String(localized: "IPA (phonetic alphabet)", bundle: .appLanguage)
        case .rtgs: return String(localized: "RTGS (official Thai)", bundle: .appLanguage)
        }
    }
}

/// The scheme views render with. Observable so any view body that reads
/// `String.romanized` re-renders when the setting changes. Kept in sync by
/// `FlashcardSettings.romanization`.
///
/// No explicit `@MainActor`: like the rest of the app it relies on the
/// project's default actor isolation, which toolchains before Swift 6.2
/// ignore. An explicit annotation breaks the build there, because
/// `FlashcardSettings` is then nonisolated.
@Observable
final class RomanizationState {
    static let shared = RomanizationState()
    var scheme: RomanizationScheme = .learner
}

extension String {
    /// This stored learner transcription, shown in the selected scheme
    var romanized: String {
        Romanization.render(self, as: RomanizationState.shared.scheme)
    }
}

extension String {
    /// Search match against this stored transcription as written and as shown
    func matchesRomanized(_ lowercasedQuery: String) -> Bool {
        lowercased().contains(lowercasedQuery) || romanized.lowercased().contains(lowercasedQuery)
    }
}

extension QuizOptions {
    /// Like `pick`, but no two options look the same in the selected scheme.
    /// RTGS writes จ and ช both as "ch": without this a card could show two
    /// identical buttons with only one graded correct.
    static func pickDistinct(correct: String, from all: some Sequence<String>, wrongCount: Int) -> [String] {
        var shown: Set<String> = [correct.romanized]
        var options: [String] = []
        for option in Set(all).subtracting([correct]).shuffled() where options.count < wrongCount {
            if shown.insert(option.romanized).inserted {
                options.append(option)
            }
        }
        options.append(correct)
        return options.shuffled()
    }
}

/// One syllable of the learner transcription, taken apart
struct ThaiSyllable: Equatable {
    enum Tone: Equatable {
        case mid, low, falling, high, rising
    }

    /// Initial consonant or cluster in learner spelling ("kh", "bpl"); empty when absent
    var onset = ""
    /// Vowel nucleus in learner spelling ("aa", "uuh"); empty in a consonant-only fragment
    var vowel = ""
    /// Final glide: "y" for ย, "o" for ว
    var glide: Character?
    /// Final consonant in learner spelling (k t p m n ng); empty when absent
    var coda = ""
    var tone: Tone = .mid
}

enum Romanization {

    // MARK: - Rendering

    /// Renders a stored learner string in `scheme`. Handles whole words
    /// ("thá-hǎan"), consonant names ("khǎaw khài"), sound fragments ("kh-",
    /// "-k"), and vowel labels ("a/aa"). Text that is not a transcription
    /// ("[silent]", "n/a") or does not parse is returned unchanged.
    static func render(_ text: String, as scheme: RomanizationScheme) -> String {
        guard scheme != .learner, let units = parse(text) else { return text }

        var rendered: [String] = []
        for alternative in units {
            let words = alternative.map { word -> String in
                switch word {
                case .onset(let onset): return renderOnset(onset, scheme) + "-"
                case .final(let final): return "-" + renderFinal(final, scheme)
                case .syllables(let syllables): return join(syllables, scheme)
                }
            }
            let joined = words.joined(separator: " ")
            // A label like "a/aa" collapses to "a" where the scheme has no length
            if !rendered.contains(joined) { rendered.append(joined) }
        }
        return rendered.joined(separator: "/")
    }

    /// Whether `text` is a well-formed learner transcription. The data tests
    /// run this over every stored string, which keeps the convention uniform.
    static func isWellFormed(_ text: String) -> Bool {
        isPassthrough(text) || parse(text) != nil
    }

    // MARK: - Parsing

    private enum Word {
        case onset(String)
        case final(String)
        case syllables([ThaiSyllable])
    }

    private static func isPassthrough(_ text: String) -> Bool {
        text.isEmpty || text.contains("[") || text == "n/a"
    }

    /// "/"-separated alternatives, each a list of space-separated words
    private static func parse(_ text: String) -> [[Word]]? {
        guard !isPassthrough(text) else { return nil }
        var alternatives: [[Word]] = []
        for alternative in text.split(separator: "/", omittingEmptySubsequences: false) {
            var words: [Word] = []
            for word in alternative.split(separator: " ", omittingEmptySubsequences: false) {
                guard let parsed = parseWord(String(word)) else { return nil }
                words.append(parsed)
            }
            alternatives.append(words)
        }
        return alternatives
    }

    private static func parseWord(_ word: String) -> Word? {
        if word.hasSuffix("-") {
            let onset = String(word.dropLast())
            return splitOnset(onset) != nil && !onset.isEmpty ? .onset(onset) : nil
        }
        if word.hasPrefix("-") {
            let final = String(word.dropFirst())
            return finals.contains(final) || final == "y" || final == "w" ? .final(final) : nil
        }
        var syllables: [ThaiSyllable] = []
        for part in word.split(separator: "-", omittingEmptySubsequences: false) {
            guard let syllable = parseSyllable(String(part)) else { return nil }
            syllables.append(syllable)
        }
        return syllables.isEmpty ? nil : .syllables(syllables)
    }

    private static let toneMarks: [Unicode.Scalar: ThaiSyllable.Tone] = [
        "\u{0300}": .low, "\u{0301}": .high, "\u{0302}": .falling, "\u{030C}": .rising,
    ]
    private static let vowelLetters: Set<Character> = ["a", "e", "i", "o", "u"]
    /// Onset consonants. "p" appears only in the ผล- row (see issue #7).
    private static let onsetBases = [
        "kh", "ng", "ch", "dt", "th", "bp", "ph",
        "g", "j", "s", "y", "d", "n", "b", "f", "m", "r", "l", "w", "h", "p",
    ]
    /// Vowel nuclei, longest first so the parse is greedy
    private static let nuclei = [
        "aae", "aaw", "euu", "eua", "uuh",
        "aa", "ae", "aw", "ee", "eu", "ia", "ii", "oh", "ua", "uh", "uu",
        "a", "e", "i", "o", "u",
    ]
    private static let finals: Set<String> = ["k", "t", "p", "m", "n", "ng"]

    static func parseSyllable(_ text: String) -> ThaiSyllable? {
        var syllable = ThaiSyllable()

        // Lift the tone diacritic off the vowel
        var letters = ""
        for scalar in text.decomposedStringWithCanonicalMapping.unicodeScalars {
            if let tone = toneMarks[scalar] {
                guard syllable.tone == .mid else { return nil }
                syllable.tone = tone
            } else if ("a"..."z").contains(Character(scalar)) {
                letters.unicodeScalars.append(scalar)
            } else {
                return nil
            }
        }

        let onset = String(letters.prefix { !vowelLetters.contains($0) })
        guard splitOnset(onset) != nil else { return nil }
        syllable.onset = onset
        var rime = Substring(letters.dropFirst(onset.count))

        // เ◌ย is spelled as a whole rime: long uh plus the ย glide
        if rime == "eeuy" {
            syllable.vowel = "uuh"
            syllable.glide = "y"
            return syllable
        }

        guard let nucleus = nuclei.first(where: { rime.hasPrefix($0) }) else { return nil }
        syllable.vowel = nucleus
        rime = rime.dropFirst(nucleus.count)

        if rime == "o" {
            syllable.glide = "o"
        } else if rime == "y" || (rime == "i" && (nucleus == "a" || nucleus == "aa")) {
            syllable.glide = "y"
        } else if finals.contains(String(rime)) {
            syllable.coda = String(rime)
        } else if !rime.isEmpty {
            return nil
        }
        return syllable
    }

    /// Splits an onset into its consonant and an optional cluster partner (r, l, w)
    private static func splitOnset(_ onset: String) -> (base: String, second: String)? {
        if onset.isEmpty { return ("", "") }
        guard let base = onsetBases.first(where: { onset.hasPrefix($0) }) else { return nil }
        let second = String(onset.dropFirst(base.count))
        return ["", "r", "l", "w"].contains(second) ? (base, second) : nil
    }

    // MARK: - Scheme tables

    private static let ipaOnsets: [String: String] = [
        "g": "k", "kh": "kʰ", "ng": "ŋ", "j": "tɕ", "ch": "tɕʰ", "s": "s", "y": "j",
        "d": "d", "dt": "t", "th": "tʰ", "n": "n", "b": "b", "bp": "p", "ph": "pʰ",
        "f": "f", "m": "m", "r": "r", "l": "l", "w": "w", "h": "h", "p": "pʰ",
    ]
    private static let rtgsOnsets: [String: String] = [
        "g": "k", "kh": "kh", "ng": "ng", "j": "ch", "ch": "ch", "s": "s", "y": "y",
        "d": "d", "dt": "t", "th": "th", "n": "n", "b": "b", "bp": "p", "ph": "ph",
        "f": "f", "m": "m", "r": "r", "l": "l", "w": "w", "h": "h", "p": "ph",
    ]
    private static let ipaVowels: [String: String] = [
        "a": "a", "aa": "aː", "i": "i", "ii": "iː", "u": "u", "uu": "uː",
        "e": "e", "ee": "eː", "ae": "ɛ", "aae": "ɛː", "o": "o", "oh": "oː",
        "aw": "ɔ", "aaw": "ɔː", "eu": "ɯ", "euu": "ɯː", "uh": "ɤ", "uuh": "ɤː",
        "ia": "ia", "eua": "ɯa", "ua": "ua",
    ]
    private static let rtgsVowels: [String: String] = [
        "a": "a", "aa": "a", "i": "i", "ii": "i", "u": "u", "uu": "u",
        "e": "e", "ee": "e", "ae": "ae", "aae": "ae", "o": "o", "oh": "o",
        "aw": "o", "aaw": "o", "eu": "ue", "euu": "ue", "uh": "oe", "uuh": "oe",
        "ia": "ia", "eua": "uea", "ua": "ua",
    ]
    private static let ipaToneMarks: [ThaiSyllable.Tone: String] = [
        .low: "\u{0300}", .high: "\u{0301}", .falling: "\u{0302}", .rising: "\u{030C}",
    ]

    private static func renderOnset(_ onset: String, _ scheme: RomanizationScheme) -> String {
        guard let (base, second) = splitOnset(onset), !base.isEmpty else { return "" }
        let table = scheme == .ipa ? ipaOnsets : rtgsOnsets
        return (table[base] ?? base) + second
    }

    private static func renderFinal(_ final: String, _ scheme: RomanizationScheme) -> String {
        switch (final, scheme) {
        case ("ng", .ipa): return "ŋ"
        case ("y", .ipa): return "j"
        case ("y", .rtgs): return "i"
        case ("o", .ipa), ("w", .ipa): return "w"
        case ("o", .rtgs), ("w", .rtgs): return "o"
        default: return final
        }
    }

    private static func renderSyllable(_ syllable: ThaiSyllable, _ scheme: RomanizationScheme) -> String {
        var vowel = (scheme == .ipa ? ipaVowels : rtgsVowels)[syllable.vowel] ?? syllable.vowel
        if scheme == .ipa, let mark = ipaToneMarks[syllable.tone], let first = vowel.first {
            vowel = "\(first)\(mark)\(vowel.dropFirst())"
        }
        let ending = syllable.glide.map { renderFinal(String($0), scheme) } ?? renderFinal(syllable.coda, scheme)
        return (renderOnset(syllable.onset, scheme) + vowel + ending).precomposedStringWithCanonicalMapping
    }

    /// IPA separates syllables with a period. RTGS writes a word solid, with a
    /// hyphen only where the break would otherwise be misread.
    private static func join(_ syllables: [ThaiSyllable], _ scheme: RomanizationScheme) -> String {
        guard scheme == .rtgs else {
            return syllables.map { renderSyllable($0, scheme) }.joined(separator: ".")
        }
        var result = ""
        for (index, syllable) in syllables.enumerated() {
            if index > 0 {
                let previous = syllables[index - 1]
                let previousEndsInVowel = previous.coda.isEmpty
                if syllable.onset.isEmpty || (previousEndsInVowel && syllable.onset.hasPrefix("ng")) {
                    result += "-"
                }
            }
            result += renderSyllable(syllable, scheme)
        }
        return result
    }
}

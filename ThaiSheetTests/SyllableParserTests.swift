//
//  SyllableParserTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

final class SyllableParserTests: XCTestCase {

    private var parser: SyllableParser!
    private var rules: [ToneRule]!
    private var marks: [ToneMark]!

    override func setUp() {
        super.setUp()
        rules = ToneRule.loadAll()
        marks = ToneMark.loadAll()
        parser = SyllableParser(
            consonants: Consonant.loadAll(),
            vowels: Vowel.loadAll(),
            clusters: Cluster.loadAll(),
            toneMarks: marks
        )
    }

    override func tearDown() {
        parser = nil
        rules = nil
        marks = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private enum Verdict: Equatable {
        case tone(String)
        case refused(String)
    }

    private func verdict(_ text: String) -> Verdict {
        switch parser.tone(of: text, rules: rules, marks: marks) {
        case .notCovered(let reason):
            return .refused("\(reason)")
        case .derived(_, let derivation):
            switch derivation.outcome {
            case .tone(let tone): return .tone(tone)
            case .notCovered(let reason): return .refused("\(reason)")
            }
        }
    }

    /// "initial|class|vowel row|duration|final|ending|mark" of the preferred reading
    private func reading(_ text: String) -> String? {
        guard case .readings(let readings) = parser.parse(text), let first = readings.first else { return nil }
        return [
            first.initial,
            first.consonantClass.rawValue,
            first.vowel.id,
            first.vowelDuration.rawValue,
            first.final ?? "",
            first.ending.rawValue,
            first.toneMark ?? "",
        ].joined(separator: "|")
    }

    /// The tone a learner transcription is written with (Paiboon-style
    /// diacritics), read independently of the app's romanization parser.
    private func tone(ofRomanization romanization: String) -> String {
        for scalar in romanization.decomposedStringWithCanonicalMapping.unicodeScalars {
            switch scalar.value {
            case 0x0300: return "Low"
            case 0x0301: return "High"
            case 0x0302: return "Falling"
            case 0x030C: return "Rising"
            default: continue
            }
        }
        return "Mid"
    }

    /// Every bundled sample word that has a romanization, deduplicated by word
    private func romanizedSampleWords() -> [(word: String, romanization: String)] {
        var samples: [ReferenceSampleWord?] = []
        samples += Consonant.loadAll().map(\.sampleWord)
        for vowel in Vowel.loadAll() {
            for set in [vowel.samples, vowel.pronunciations] {
                samples += [set?.short_closed, set?.short_open, set?.long_closed, set?.long_open]
            }
        }
        samples += Cluster.loadAll().map(\.sample)
        for mark in marks {
            samples += [mark.samples?.low, mark.samples?.mid, mark.samples?.high]
        }
        for rule in rules {
            for sample in rule.samples ?? [] {
                samples.append(ReferenceSampleWord(word: sample.full, romanization: sample.romanization))
            }
        }

        var seen: Set<String> = []
        var result: [(word: String, romanization: String)] = []
        for sample in samples {
            guard let sample, let romanization = sample.romanization, seen.insert(sample.word).inserted else {
                continue
            }
            result.append((sample.word, romanization))
        }
        return result
    }

    private func isOneSyllable(_ romanization: String) -> Bool {
        !romanization.contains("-") && !romanization.contains(" ")
    }

    // MARK: - Readings

    func test_readings_statePartsOfTheSyllable() {
        XCTAssertEqual(reading("กา"), "ก|mid|a|Long||Live|")
        XCTAssertEqual(reading("คะ"), "ค|low|a|Short||Dead|")
        XCTAssertEqual(reading("มาก"), "ม|low|a|Long|ก|Dead|")
        XCTAssertEqual(reading("คน"), "ค|low|o|Short|น|Live|")
        XCTAssertEqual(reading("กลม"), "กล|mid|o|Short|ม|Live|")
        XCTAssertEqual(reading("ข้าว"), "ข|high|ao|Long||Live|้")
        XCTAssertEqual(reading("เพื่อน"), "พ|low|uea|Long|น|Live|่")
        XCTAssertEqual(reading("น้ำ"), "น|low|am|Short||Live|้")
        XCTAssertEqual(reading("เพราะ"), "พร|low|aw|Short||Dead|")
        XCTAssertEqual(reading("ไทย"), "ท|low|ai-mai-malai-ya|Short||Live|")
    }

    func test_leadingHo_givesTheSyllableHighClass() {
        XCTAssertEqual(reading("หนา"), "หน|high|a|Long||Live|")
        XCTAssertEqual(verdict("หนา"), .tone("Rising"))
        XCTAssertEqual(verdict("นา"), .tone("Mid"))
        XCTAssertEqual(verdict("ใหม่"), .tone("Low"))
        XCTAssertEqual(verdict("หมด"), .tone("Low"))
    }

    func test_silencedLastLetter_isIgnored() {
        XCTAssertEqual(reading("สัตว์"), "ส|high|a|Short|ต|Dead|")
        XCTAssertEqual(verdict("สัตว์"), .tone("Low"))
        XCTAssertEqual(verdict("สิทธิ์"), .tone("Low"))
    }

    func test_finalCluster_fromTheClusterTable() {
        XCTAssertEqual(reading("มุทร"), "ม|low|u|Short|ทร|Dead|")
    }

    /// กาย fits ◌าย and also ◌า plus a final ย: both are long and live
    func test_spellingWithSeveralReadings_isAcceptedWhenTheyAgree() {
        guard case .readings(let readings) = parser.parse("กาย") else { return XCTFail("กาย should parse") }
        XCTAssertEqual(readings.map(\.vowel.id), ["aai", "a"])
        XCTAssertEqual(verdict("กาย"), .tone("Mid"))
    }

    // MARK: - Refusals

    func test_inputThatIsNotOneThaiSyllable_isRefused() {
        XCTAssertEqual(verdict(""), .refused("empty"))
        XCTAssertEqual(verdict("   "), .refused("empty"))
        XCTAssertEqual(verdict("maa"), .refused("notThaiScript"))
        XCTAssertEqual(verdict("มา มา"), .refused("notThaiScript"))
        XCTAssertEqual(verdict("ม่้า"), .refused("severalToneMarks"))
        // A lone consonant, and ก็ (falling with no written vowel or mark)
        XCTAssertEqual(verdict("ก"), .refused("noKnownPattern"))
        XCTAssertEqual(verdict("ก็"), .refused("noKnownPattern"))
        // Tone mark on the final consonant
        XCTAssertEqual(verdict("มาก่"), .refused("noKnownPattern"))
    }

    func test_wordsOfSeveralSyllables_areRefused() {
        // Unwritten vowel between the first two consonants
        for word in ["ขนม", "ตลาด", "สบาย", "ถนน", "ทหาร", "อร่อย", "เสมอ", "แสดง"] {
            XCTAssertEqual(verdict(word), .refused("noKnownPattern"), word)
        }
        for word in ["มะนาว", "สวัสดี", "ภาษา", "กาแฟ"] {
            XCTAssertEqual(verdict(word), .refused("noKnownPattern"), word)
        }
    }

    /// Leading อ (อยู่, อย่า, อย่าง, อยาก) is not in the cluster table. Read as
    /// ย with a mark it would be Falling instead of Low, so it must refuse.
    func test_leadingO_isRefused() {
        for word in ["อยู่", "อย่า", "อย่าง", "อยาก"] {
            XCTAssertEqual(verdict(word), .refused("noKnownPattern"), word)
        }
    }

    /// เ◌ิ- is written the same short and long. For a low-class dead syllable
    /// the two lengths give different tones, so the parser cannot decide.
    func test_spellingWhoseReadingsGiveDifferentTones_isRefused() {
        XCTAssertEqual(verdict("เลิก"), .refused("readingsDisagree"))
        // Same spelling problem, but mid class reads Low either way
        XCTAssertEqual(verdict("เกิด"), .tone("Low"))
        // ควบ: ค + ◌ว◌ + บ (long), or คว- + unwritten vowel + บ (short)
        XCTAssertEqual(verdict("ควบ"), .refused("readingsDisagree"))
    }

    /// พร is ph + long ◌อ + n and สรร is s + an. The vowel forms in the data
    /// do not list these spellings, and reading them with the unwritten
    /// short vowel would state the wrong vowel and length.
    func test_unwrittenVowelBeforeFinalRo_isRefused() {
        for word in ["พร", "ศร", "กร", "จร", "สรร"] {
            XCTAssertEqual(verdict(word), .refused("noKnownPattern"), word)
        }
        // A final ร after a written vowel is unaffected, before or after the initial
        XCTAssertEqual(reading("การ"), "ก|mid|a|Long|ร|Live|")
        XCTAssertEqual(reading("เณร"), "ณ|low|e|Long|ร|Live|")
        // ควร keeps its one written-vowel reading, ค + ◌ว◌ + ร
        guard case .readings(let readings) = parser.parse("ควร") else { return XCTFail("ควร should parse") }
        XCTAssertEqual(readings.map(\.vowel.id), ["ua"])
        XCTAssertEqual(verdict("ควร"), .tone("Mid"))
    }

    func test_midOnlyMarkOnAnotherClass_isRefused() {
        XCTAssertEqual(verdict("ค๊า"), .refused("markNotUsedWithClass"))
    }

    // MARK: - Known limit

    /// A two-syllable word whose first two letters also form a cluster is
    /// indistinguishable from one syllable without a dictionary: พลัง is
    /// phá-lang, and reads here as one syllable "phlang". This is the case a
    /// learner-facing feature has to guard against (show the reading, ask
    /// for one syllable). Pinned so the limit stays visible.
    func test_knownLimit_twoSyllableWordWithClusterLikeOnset_readsAsOneSyllable() {
        XCTAssertEqual(reading("พลัง"), "พล|low|a|Short|ง|Live|")
        XCTAssertEqual(verdict("พลัง"), .tone("Mid"))
    }

    // MARK: - Bundled sample words as a corpus

    /// Words the data itself documents as spoken against the tone rules
    /// (the บล- cluster note), with the tone the rules give. No parser can
    /// know these from the spelling: the derived tone is the spelled one.
    private let documentedExceptions = ["บล็อก": "Low"]

    /// Every one-syllable sample word with a romanization: the tone the
    /// parser derives must be the tone the romanization is written with.
    /// A refusal is acceptable, a different tone is not.
    func test_corpus_oneSyllableSampleWords_neverDeriveAWrongTone() {
        var correct = 0
        var exceptions = 0
        var refused: [String] = []
        var wrong: [String] = []
        let words = romanizedSampleWords().filter { isOneSyllable($0.romanization) }
        for (word, romanization) in words {
            let expected = tone(ofRomanization: romanization)
            if let spelledTone = documentedExceptions[word] {
                XCTAssertNotEqual(expected, spelledTone, "\(word) is no longer an exception")
                XCTAssertEqual(verdict(word), .tone(spelledTone), word)
                exceptions += 1
                continue
            }
            switch verdict(word) {
            case .tone(expected): correct += 1
            case .tone(let tone): wrong.append("\(word) \(romanization): derived \(tone)")
            case .refused(let reason): refused.append("\(word) \(romanization): \(reason)")
            }
        }
        print("SYLLABLE-CORPUS words total=\(words.count) correct=\(correct) refused=\(refused.count) "
            + "documentedExceptions=\(exceptions) wrong=\(wrong.count)")
        refused.forEach { print("SYLLABLE-CORPUS words refused: \($0)") }
        wrong.forEach { print("SYLLABLE-CORPUS words wrong: \($0)") }
        XCTAssertEqual(wrong, [])
        XCTAssertEqual(exceptions, documentedExceptions.count)
        XCTAssertGreaterThan(words.count, 100)
    }

    /// Every tone-rule sample's focus syllable: the parser must reach the
    /// rule the sample is filed under, or refuse.
    func test_corpus_toneRuleFocusSyllables_neverDeriveAWrongRule() {
        var total = 0
        var correct = 0
        var refused: [String] = []
        var wrong: [String] = []
        for rule in rules {
            for sample in rule.samples ?? [] {
                total += 1
                let label = "\(rule.id) \(sample.id) \(sample.focus)"
                switch parser.tone(of: sample.focus, rules: rules, marks: marks) {
                case .notCovered(let reason):
                    refused.append("\(label): \(reason)")
                case .derived(_, let derivation):
                    guard case .toneRule(let matched)? = derivation.decidingStep else {
                        wrong.append("\(label): \(derivation.outcome)")
                        continue
                    }
                    if matched.id == rule.id {
                        correct += 1
                    } else {
                        wrong.append("\(label): matched \(matched.id)")
                    }
                }
            }
        }
        print("SYLLABLE-CORPUS focus total=\(total) correct=\(correct) refused=\(refused.count) wrong=\(wrong.count)")
        refused.forEach { print("SYLLABLE-CORPUS focus refused: \($0)") }
        wrong.forEach { print("SYLLABLE-CORPUS focus wrong: \($0)") }
        XCTAssertEqual(wrong, [])
        XCTAssertEqual(total, 98)
    }

    /// Sample words of several syllables should be refused. One that parses
    /// as a single syllable would be answered wrongly without warning.
    func test_corpus_multiSyllableSampleWords_areRefused() {
        var accepted: [String] = []
        var candidates: [String] = romanizedSampleWords()
            .filter { !isOneSyllable($0.romanization) }
            .map(\.word)
        for rule in rules {
            for sample in rule.samples ?? [] where sample.full != sample.focus {
                candidates.append(sample.full)
            }
        }
        let words = Array(Set(candidates)).sorted()
        for word in words {
            if case .tone(let tone) = verdict(word) {
                accepted.append("\(word): \(tone)")
            }
        }
        print("SYLLABLE-CORPUS multi total=\(words.count) accepted=\(accepted.count)")
        accepted.forEach { print("SYLLABLE-CORPUS multi accepted: \($0)") }
        XCTAssertEqual(accepted, [])
        XCTAssertGreaterThan(words.count, 20)
    }
}

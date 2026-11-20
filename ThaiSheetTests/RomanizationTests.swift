//
//  RomanizationTests.swift
//  ThaiSheetTests
//

import SwiftUI
import XCTest
@testable import ThaiSheet

final class RomanizationTests: XCTestCase {

    override func tearDown() {
        RomanizationState.shared.scheme = .learner
        super.tearDown()
    }

    // MARK: - The stored convention

    /// Every romanized string in the data files, with the file it came from
    private func storedStrings() throws -> [(file: String, text: String)] {
        var found: [(String, String)] = []
        func walk(_ value: Any, file: String) {
            if let dictionary = value as? [String: Any] {
                for (key, child) in dictionary {
                    if let text = child as? String,
                       ["romanization", "transcription", "initial", "final", "sound"].contains(key) {
                        found.append((file, text))
                    } else if key == "sounds", let sounds = child as? [String: Any], let label = sounds["en"] as? String {
                        found.append((file, label))
                    } else {
                        walk(child, file: file)
                    }
                }
            } else if let array = value as? [Any] {
                array.forEach { walk($0, file: file) }
            }
        }
        for file in ["consonants", "vowels", "clusters", "tone-marks", "tone-rules"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: file, withExtension: "json"))
            walk(try JSONSerialization.jsonObject(with: Data(contentsOf: url)), file: file)
        }
        return found
    }

    func test_everyStoredString_followsTheLearnerConvention() throws {
        let strings = try storedStrings()
        XCTAssertGreaterThan(strings.count, 300)
        for (file, text) in strings {
            XCTAssertTrue(Romanization.isWellFormed(text),
                          "\(file).json: \"\(text)\" does not follow the learner transcription convention")
        }
    }

    func test_everyStoredString_rendersInEveryScheme() throws {
        for (_, text) in try storedStrings() {
            for scheme in RomanizationScheme.allCases {
                XCTAssertFalse(Romanization.render(text, as: scheme).isEmpty && !text.isEmpty)
            }
        }
    }

    // MARK: - Parsing

    func test_parseSyllable_separatesOnsetVowelEndingAndTone() {
        XCTAssertEqual(Romanization.parseSyllable("khǎaw"),
                       ThaiSyllable(onset: "kh", vowel: "aaw", glide: nil, coda: "", tone: .rising))
        XCTAssertEqual(Romanization.parseSyllable("bplaa"),
                       ThaiSyllable(onset: "bpl", vowel: "aa", glide: nil, coda: "", tone: .mid))
        XCTAssertEqual(Romanization.parseSyllable("phêung"),
                       ThaiSyllable(onset: "ph", vowel: "eu", glide: nil, coda: "ng", tone: .falling))
        XCTAssertEqual(Romanization.parseSyllable("khǐao"),
                       ThaiSyllable(onset: "kh", vowel: "ia", glide: "o", coda: "", tone: .rising))
        XCTAssertEqual(Romanization.parseSyllable("leeuy"),
                       ThaiSyllable(onset: "l", vowel: "uuh", glide: "y", coda: "", tone: .mid))
        XCTAssertEqual(Romanization.parseSyllable("àang"),
                       ThaiSyllable(onset: "", vowel: "aa", glide: nil, coda: "ng", tone: .low))
    }

    func test_parseSyllable_rejectsSpellingsOutsideTheConvention() {
        for bad in ["dern", "dee x", "khuuen", "leery", "lôok", "hǐw", "Gaa"] {
            XCTAssertFalse(Romanization.isWellFormed(bad), "\"\(bad)\" should be rejected")
        }
    }

    // MARK: - Rendering

    func test_learnerScheme_returnsTheStoredString() {
        XCTAssertEqual(Romanization.render("khǎaw khài", as: .learner), "khǎaw khài")
    }

    func test_paiboon_respellsStopsAndVowels_keepsToneLengthAndHyphens() {
        XCTAssertEqual(Romanization.render("khǎaw khài", as: .paiboon), "kɔ̌ɔ kài")
        XCTAssertEqual(Romanization.render("thá-hǎan", as: .paiboon), "tá-hǎan")
        XCTAssertEqual(Romanization.render("bpà-dtàk", as: .paiboon), "bpà-dtàk")
        XCTAssertEqual(Romanization.render("gaaeng", as: .paiboon), "gɛɛng")
        XCTAssertEqual(Romanization.render("phêung", as: .paiboon), "pʉ̂ng")
        XCTAssertEqual(Romanization.render("meuang", as: .paiboon), "mʉang")
        XCTAssertEqual(Romanization.render("nguhn", as: .paiboon), "ngən")
        XCTAssertEqual(Romanization.render("dtoh", as: .paiboon), "dtoo")
        XCTAssertEqual(Romanization.render("jaan", as: .paiboon), "jaan")
    }

    func test_paiboon_glideEndings() {
        XCTAssertEqual(Romanization.render("leeuy", as: .paiboon), "ləəi")
        XCTAssertEqual(Romanization.render("sǔay", as: .paiboon), "sǔai")
        XCTAssertEqual(Romanization.render("khaawy", as: .paiboon), "kɔɔi")
        XCTAssertEqual(Romanization.render("dohy", as: .paiboon), "dooi")
        XCTAssertEqual(Romanization.render("khǐao", as: .paiboon), "kǐao")
        XCTAssertEqual(Romanization.render("leeo", as: .paiboon), "leeo")
        XCTAssertEqual(Romanization.render("hǐo", as: .paiboon), "hǐu", "◌ิว is the one ว glide written u")
    }

    func test_paiboon_fragmentsAndLabels() {
        XCTAssertEqual(Romanization.render("kh-", as: .paiboon), "k-")
        XCTAssertEqual(Romanization.render("g-", as: .paiboon), "g-")
        XCTAssertEqual(Romanization.render("-y", as: .paiboon), "-i")
        XCTAssertEqual(Romanization.render("o/oh", as: .paiboon), "o/oo")
        XCTAssertEqual(Romanization.render("eu/euu", as: .paiboon), "ʉ/ʉʉ")
        XCTAssertEqual(Romanization.render("io", as: .paiboon), "iu")
        XCTAssertEqual(Romanization.render("phl-", as: .paiboon), Romanization.render("pl-", as: .paiboon),
                       "พล- and ผล- look alike in Paiboon, so quiz options rely on pickDistinct")
    }

    func test_ipa_keepsToneAndLength() {
        XCTAssertEqual(Romanization.render("khǎaw khài", as: .ipa), "kʰɔ̌ː kʰàj")
        XCTAssertEqual(Romanization.render("thá-hǎan", as: .ipa), "tʰá.hǎːn")
        XCTAssertEqual(Romanization.render("gaaeng", as: .ipa), "kɛːŋ")
        XCTAssertEqual(Romanization.render("jaan", as: .ipa), "tɕaːn")
        XCTAssertEqual(Romanization.render("leeuy", as: .ipa), "lɤːj")
        XCTAssertEqual(Romanization.render("hǐo", as: .ipa), "hǐw")
        XCTAssertEqual(Romanization.render("nguhn", as: .ipa), "ŋɤn")
    }

    func test_rtgs_dropsToneAndLength() {
        XCTAssertEqual(Romanization.render("khǎaw khài", as: .rtgs), "kho khai")
        XCTAssertEqual(Romanization.render("thá-hǎan", as: .rtgs), "thahan")
        XCTAssertEqual(Romanization.render("gaaeng", as: .rtgs), "kaeng")
        XCTAssertEqual(Romanization.render("jaan", as: .rtgs), "chan")
        XCTAssertEqual(Romanization.render("cháang", as: .rtgs), "chang")
        XCTAssertEqual(Romanization.render("leeuy", as: .rtgs), "loei")
        XCTAssertEqual(Romanization.render("sǔay", as: .rtgs), "suai")
        XCTAssertEqual(Romanization.render("meuang", as: .rtgs), "mueang")
        XCTAssertEqual(Romanization.render("dtrong", as: .rtgs), "trong")
        XCTAssertEqual(Romanization.render("bplaa", as: .rtgs), "pla")
    }

    func test_rtgs_hyphenatesOnlyWhereTheBreakIsAmbiguous() {
        XCTAssertEqual(Romanization.render("sà-àat", as: .rtgs), "sa-at")
        XCTAssertEqual(Romanization.render("sà-ngàa", as: .rtgs), "sa-nga")
        XCTAssertEqual(Romanization.render("jù-laa", as: .rtgs), "chula")
    }

    func test_bookRendersWordsWithItsOwnVowelsTonesAndBoundaries() {
        let examples: [(learner: String, expected: String)] = [
            ("khǎaw khài", "kŏr kài"), ("thaaw thá-hǎan", "tor táhăan"),
            ("phêung", "pûe’ng"), ("gàawn", "gòrn"), ("khon", "kon"),
            ("khun", "koo’n"), ("bplaa", "bplaa"), ("dtrong", "dtrong"),
            ("gà", "gà"), ("gan", "gun"), ("dtè", "dtày’"), ("dèk", "dèk"),
            ("gaaeng", "gang"), ("khǎeng", "kă’ng"), ("gàe", "gàir’"),
            ("dii", "dee"), ("lôhk", "lôhk"), ("dtó", "dtó’"),
            ("gàw", "gòr’"), ("juuh", "jer"), ("nguhn", "ngern"),
            ("jam", "jum"), ("àang", "àang"), ("meuang", "mueang"),
            ("leeuy", "leui"), ("dohy", "doey"), ("khaawy", "koi"),
            ("hǐo", "hĭw"), ("khǐao", "kĭao"), ("sǔay", "sŭai"),
            ("nèuay", "nùeai"), ("khuy", "kui"), ("dtào", "dtào"),
            ("sà-àat", "sà-àat"), ("rohng-raaem", "rohng-ram"),
            ("sà-ngàa", "sà-ngàa"), ("jàt-dtà-waa", "jùt-dtàwaa"),
            // Open ◌ุ is u and closed is oo’. The book prints ดุ dòo’ (p. 55),
            // an exception this scheme does not follow.
            ("jù", "jù"), ("jù-laa", "jùlaa"), ("dù", "dù"), ("bùk", "bòo’k"),
            // The book hyphenates before dt and bp by default.
            ("bpà-dtàk", "bpà-dtùk"), ("dtà-bpuu", "dtà-bpoo"),
            // Appendix II (pp. 141, 143)
            ("dtaaw bpà-dtàk", "dtor bpà-dtùk"), ("laaw jù-laa", "lor jùlaa"),
        ]
        for (learner, expected) in examples {
            XCTAssertEqual(Romanization.render(learner, as: .readThaiIn10Days), expected, learner)
        }
    }

    func test_bookUsesABreveAndCanonicalUnicode() {
        XCTAssertEqual(
            Romanization.render("gaa gàa gâa gáa gǎa", as: .readThaiIn10Days),
            "gaa gàa gâa gáa găa"
        )
        let decomposedLearner = "khǎaw".decomposedStringWithCanonicalMapping
        let rendered = Romanization.render(decomposedLearner, as: .readThaiIn10Days)
        XCTAssertEqual(Array(rendered.unicodeScalars), Array("kŏr".unicodeScalars))
        XCTAssertFalse(Romanization.isWellFormed(rendered), "Book output is not a learner input")
    }

    func test_bookFragmentsAndVowelLabels() {
        let examples = [
            "khr-": "kr-", "th-": "t-", "bp-": "bp-", "j-/ch-": "j-/ch-",
            "-y/-w/-ng": "-i/-o/-ng", "phl-/pl-": "pl-",
            "a/aa": "a/aa", "e/ee": "ay’/ay", "eu/euu": "ue’/ue",
            "aeo/aaeo": "aeo’/aeo", "eo/eeo": "eo’/eo", "awy/aawy": "oi’/oi",
            "uuho": "ero", "u/uu": "oo’/oo", "ia": "ia’/ia", "eua": "uea’/uea", "ua": "ua’/ua",
        ]
        for (learner, expected) in examples {
            XCTAssertEqual(Romanization.render(learner, as: .readThaiIn10Days, context: .vowelLabel), expected)
        }
    }

    func test_bookShortDiphthongsUseTheExampleContext() throws {
        let vowels = Vowel.loadAll()
        for (id, expected) in [("ia", "gía’"), ("ua", "pùa’")] {
            let vowel = try XCTUnwrap(vowels.first { $0.id == id })
            let sample = try XCTUnwrap(vowel.pronunciation(for: .short, form: .open)?.romanization)
            XCTAssertEqual(
                Romanization.render(sample, as: .readThaiIn10Days, context: .shortOpenVowelExample),
                expected
            )
            XCTAssertEqual(Romanization.render(sample, as: .readThaiIn10Days), String(expected.dropLast()))
            XCTAssertEqual(Romanization.render(sample, as: .learner, context: .shortOpenVowelExample), sample)
        }
        XCTAssertEqual(Romanization.render("héua", as: .readThaiIn10Days, context: .shortOpenVowelExample), "húea’")
        XCTAssertEqual(Romanization.render("rian", as: .readThaiIn10Days, context: .shortOpenVowelExample), "rian")
    }

    func test_fragmentsAndLabels() {
        XCTAssertEqual(Romanization.render("kh-", as: .ipa), "kʰ-")
        XCTAssertEqual(Romanization.render("j-", as: .rtgs), "ch-")
        XCTAssertEqual(Romanization.render("-ng", as: .ipa), "-ŋ")
        XCTAssertEqual(Romanization.render("-y", as: .rtgs), "-i")
        XCTAssertEqual(Romanization.render("a/aa", as: .ipa), "a/aː")
        XCTAssertEqual(Romanization.render("a/aa", as: .rtgs), "a", "RTGS has no length, so the pair collapses")
        XCTAssertEqual(Romanization.render("uh/uuh", as: .rtgs), "oe")
    }

    func test_textThatIsNotATranscription_isLeftAlone() {
        for text in ["[silent]", "[vowel]", "n/a", "(silent)", ""] {
            for scheme in RomanizationScheme.allCases {
                XCTAssertEqual(Romanization.render(text, as: scheme), text)
            }
        }
    }

    // MARK: - Quiz options and search

    func test_pickDistinct_neverOffersTwoOptionsThatLookAlike() {
        RomanizationState.shared.scheme = .rtgs
        let initials = Consonant.loadAll().map(\.initialSound)
        for _ in 0..<50 {
            let options = QuizOptions.pickDistinct(correct: "j-", from: initials, wrongCount: 7)
            XCTAssertTrue(options.contains("j-"))
            let shown = options.map(\.romanized)
            XCTAssertEqual(shown.count, Set(shown).count, "Two options render the same: \(shown)")
            XCTAssertFalse(options.contains("ch-"), "ch- looks identical to the correct j- in RTGS")
        }
    }

    func test_summaryRow_gradesTheStoredAnswer_notHowItLooks() {
        // j- and ch- both read "ch-" in RTGS. A wrong ch- must stay wrong
        // when the scheme changes after the card was answered.
        RomanizationState.shared.scheme = .rtgs
        let wrong = FlashcardSummaryRow(
            label: "Initial", selectedValue: "ch-", correctValue: "j-",
            showResult: true, display: \.romanized
        )
        XCTAssertEqual(wrong.display("ch-"), wrong.display("j-"))
        XCTAssertFalse(wrong.isCorrect)

        let right = FlashcardSummaryRow(
            label: "Initial", selectedValue: "j-", correctValue: "j-",
            showResult: true, display: \.romanized
        )
        XCTAssertTrue(right.isCorrect)
    }

    func test_search_matchesStoredAndShownSpellings() {
        RomanizationState.shared.scheme = .rtgs
        XCTAssertTrue("g-".matchesRomanized("g"), "The stored spelling still matches")
        XCTAssertTrue("g-".matchesRomanized("k"), "The shown spelling matches too")
        XCTAssertFalse("g-".matchesRomanized("ph"))
    }

    func test_bookSearchChecksStoredAndDisplayedLabelsAndBothApostrophes() {
        RomanizationState.shared.scheme = .readThaiIn10Days
        XCTAssertTrue("kh-".matchesRomanized("kh"))
        XCTAssertTrue("kh-".matchesRomanized("k-"))
        XCTAssertTrue("phr-".matchesRomanized("pr"))
        XCTAssertTrue("eu/euu".matchesRomanized("ue’", context: .vowelLabel))
        XCTAssertTrue("eu/euu".matchesRomanized("ue'", context: .vowelLabel))
        XCTAssertTrue("eua".matchesRomanized("uea'/", context: .vowelLabel))
        XCTAssertFalse("eua".matchesRomanized("uea'/"))
        XCTAssertFalse("eua".matchesRomanized("way", context: .vowelLabel))
        RomanizationState.shared.scheme = .learner
        XCTAssertFalse("eu/euu".matchesRomanized("ue'", context: .vowelLabel))
    }

    func test_bookClusterCollisionKeepsTheRawCorrectAnswerAndGrade() {
        RomanizationState.shared.scheme = .readThaiIn10Days
        let options = QuizOptions.pickDistinct(correct: "phl-", from: ["phl-", "pl-", "bpl-"], wrongCount: 7)
        XCTAssertEqual(Set(options), ["phl-", "bpl-"])
        let summary = FlashcardSummaryRow(
            label: "Sound", selectedValue: "pl-", correctValue: "phl-", showResult: true, display: \.romanized
        )
        XCTAssertEqual(summary.display("pl-"), summary.display("phl-"))
        XCTAssertFalse(summary.isCorrect)
    }

    func test_bookPreservesDistinctDisplayedOptionsAcrossCatalogs() {
        RomanizationState.shared.scheme = .readThaiIn10Days
        let consonants = Consonant.loadAll()
        let pools: [(options: [String], context: RomanizationContext, wrongCount: Int)] = [
            (consonants.map(\.initialSound), .transcription, 7),
            (consonants.map(\.finalSound), .transcription, 3),
            (Cluster.loadAll().compactMap(\.sound), .transcription, 3),
            (Vowel.loadAll().map(\.sound), .vowelLabel, 7),
        ]
        for (pool, context, wrongCount) in pools {
            let available = Set(pool.map { $0.romanized(in: context) }).count
            for correct in Set(pool) {
                let choices = QuizOptions.pickDistinct(
                    correct: correct, from: pool, wrongCount: wrongCount, context: context
                )
                XCTAssertEqual(choices.filter { $0 == correct }.count, 1)
                XCTAssertEqual(Set(choices.map { $0.romanized(in: context) }).count, choices.count)
                XCTAssertEqual(choices.count, min(wrongCount + 1, available))
            }
        }
        for consonant in consonants {
            let choices = ConsonantFlashcardView.transcriptionOptions(for: consonant, from: consonants)
            XCTAssertEqual(choices.filter { $0 == consonant.transcription }.count, 1)
            XCTAssertEqual(Set(choices.map(\.romanized)).count, 4)
        }
    }

    // MARK: - Setting

    func test_setting_persistsAndDrivesTheSharedState() {
        let suite = "RomanizationTests_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = FlashcardSettings(defaults: defaults)
        XCTAssertEqual(settings.romanization, .learner)
        settings.romanization = .ipa
        XCTAssertEqual(RomanizationState.shared.scheme, .ipa)
        XCTAssertEqual("gaa".romanized, "kaː")

        let reloaded = FlashcardSettings(defaults: defaults)
        XCTAssertEqual(reloaded.romanization, .ipa)
        XCTAssertTrue(FlashcardSettings.syncedKeys.contains("fc_romanization"))
    }

    func test_settingReloadsBookAndPreviouslyStoredSchemes() {
        let suite = "RomanizationTests_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = FlashcardSettings(defaults: defaults)
        settings.romanization = .readThaiIn10Days
        XCTAssertEqual(defaults.string(forKey: "fc_romanization"), "readThaiIn10Days")
        XCTAssertEqual("khǎaw".romanized, "kŏr")
        for scheme in RomanizationScheme.allCases {
            defaults.set(scheme.rawValue, forKey: "fc_romanization")
            settings.reload()
            XCTAssertEqual(settings.romanization, scheme)
            XCTAssertEqual(RomanizationState.shared.scheme, scheme)
        }
        defaults.set("unknown", forKey: "fc_romanization")
        settings.reload()
        XCTAssertEqual(settings.romanization, .learner)
        XCTAssertEqual(RomanizationState.shared.scheme, .learner)
    }
}

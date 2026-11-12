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
}

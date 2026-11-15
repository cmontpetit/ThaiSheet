//
//  ToneFinderTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

final class ToneFinderTests: XCTestCase {

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

    private func resolve(_ finder: ToneFinder) -> ToneFinder.Resolution {
        finder.resolve(parser: parser, rules: rules, marks: marks)
    }

    private func finder(text: String) -> ToneFinder {
        var finder = ToneFinder()
        finder.text = text
        return finder
    }

    // MARK: - Reading the text

    func test_emptySheet_startsOnNoMarkWithNothingElseSet() {
        let resolution = resolve(ToneFinder())
        XCTAssertFalse(resolution.textNotRead)
        XCTAssertEqual(resolution.mark, ToneFinder.MarkChoice.none)
        XCTAssertNil(resolution.consonantClass)
        XCTAssertNil(resolution.ending)
        XCTAssertNil(resolution.duration)
        XCTAssertNil(resolution.derivation)
        XCTAssertNil(resolution.notice)
    }

    func test_unmarkedSyllable_fillsTheFactsAndDerivesTheTone() {
        let resolution = resolve(finder(text: "หนา"))
        XCTAssertEqual(resolution.reading?.initial, "หน")
        XCTAssertEqual(resolution.consonantClass, .high)
        XCTAssertEqual(resolution.mark, ToneFinder.MarkChoice.none)
        XCTAssertEqual(resolution.ending, .live)
        XCTAssertEqual(resolution.duration, .long)
        XCTAssertEqual(resolution.derivation?.tone, "Rising")
        XCTAssertTrue(resolution.usesEndingAndDuration)
    }

    func test_markedSyllable_decidesWithTheMarkAndClass() {
        let resolution = resolve(finder(text: "ข้าว"))
        XCTAssertEqual(resolution.mark, .mark("้"))
        XCTAssertEqual(resolution.consonantClass, .high)
        XCTAssertEqual(resolution.derivation?.tone, "Falling")
        XCTAssertFalse(resolution.usesEndingAndDuration)
    }

    func test_surroundingWhitespace_isIgnored() {
        XCTAssertEqual(resolve(finder(text: " มา\n")).derivation?.tone, "Mid")
    }

    /// สวน reads as ส + ◌ว◌ + น before สว- is tried as an initial
    func test_shownReading_isTheMostLikelyOne() {
        let resolution = resolve(finder(text: "สวน"))
        XCTAssertEqual(resolution.reading?.initial, "ส")
        XCTAssertEqual(resolution.reading?.vowel.id, "ua")
        XCTAssertEqual(resolution.derivation?.tone, "Rising")
    }

    // MARK: - Spelling that leaves a fact open

    func test_spellingWithoutVowelLength_asksForItThenDerives() {
        var finder = finder(text: "เลิก")
        var resolution = resolve(finder)
        XCTAssertFalse(resolution.textNotRead)
        XCTAssertEqual(resolution.consonantClass, .low)
        XCTAssertEqual(resolution.ending, .dead)
        XCTAssertNil(resolution.duration)
        XCTAssertNil(resolution.derivation)
        XCTAssertEqual(resolution.notice, .chooseVowelLength)

        finder.chosenDuration = .long
        resolution = resolve(finder)
        XCTAssertEqual(resolution.derivation?.tone, "Falling")
        XCTAssertNil(resolution.notice)

        finder.chosenDuration = .short
        XCTAssertEqual(resolve(finder).derivation?.tone, "High")
    }

    /// เกิด has the same open length, but mid class reads Low either way
    func test_openVowelLength_isNotAskedWhenItDoesNotMatter() {
        let resolution = resolve(finder(text: "เกิด"))
        XCTAssertNil(resolution.duration)
        XCTAssertEqual(resolution.derivation?.tone, "Low")
        XCTAssertNil(resolution.notice)
    }

    // MARK: - Text that cannot be read

    func test_unreadText_leavesEveryFactUnset() {
        let resolution = resolve(finder(text: "ขนม"))
        XCTAssertTrue(resolution.textNotRead)
        XCTAssertNil(resolution.reading)
        XCTAssertNil(resolution.consonantClass)
        // Not defaulted to "no mark": the text may carry one
        XCTAssertNil(resolution.mark)
        XCTAssertNil(resolution.ending)
        XCTAssertNil(resolution.derivation)
        XCTAssertNil(resolution.notice)
    }

    func test_unreadText_canBeCompletedByHand() {
        var finder = finder(text: "ขนม")
        finder.chosenClass = .high
        finder.chosenMark = ToneFinder.MarkChoice.none
        finder.chosenEnding = .live
        let resolution = resolve(finder)
        XCTAssertTrue(resolution.textNotRead)
        XCTAssertEqual(resolution.derivation?.tone, "Rising")
    }

    // MARK: - Hand-set facts

    func test_factsSetByHandAlone_deriveTheTone() {
        var finder = ToneFinder()
        finder.chosenClass = .low
        finder.chosenEnding = .dead
        XCTAssertEqual(resolve(finder).notice, .chooseVowelLength)

        finder.chosenDuration = .short
        XCTAssertEqual(resolve(finder).derivation?.tone, "High")

        finder.chosenMark = .mark("่")
        XCTAssertEqual(resolve(finder).derivation?.tone, "Falling")
    }

    func test_handSetFact_winsOverTheReading() {
        var finder = finder(text: "นา")
        XCTAssertEqual(resolve(finder).derivation?.tone, "Mid")
        finder.chosenClass = .high
        let resolution = resolve(finder)
        XCTAssertEqual(resolution.consonantClass, .high)
        XCTAssertEqual(resolution.derivation?.tone, "Rising")
    }

    func test_editingTheText_discardsHandSetFacts() {
        var finder = finder(text: "นา")
        finder.chosenClass = .high
        finder.chosenMark = .mark("่")
        finder.chosenEnding = .dead
        finder.chosenDuration = .short

        finder.text = "มา"
        XCTAssertNil(finder.chosenClass)
        XCTAssertNil(finder.chosenMark)
        XCTAssertNil(finder.chosenEnding)
        XCTAssertNil(finder.chosenDuration)
        XCTAssertEqual(resolve(finder).derivation?.tone, "Mid")
    }

    // MARK: - Reading notes

    private typealias Note = ToneFinder.ReadingNote

    private func notes(_ text: String) -> [Note] {
        resolve(finder(text: text)).readingNotes
    }

    func test_notes_singleConsonantClosedSyllable() {
        XCTAssertEqual(notes("มาก"), [
            .consonantClass(letter: "ม", .low),
            .vowelLength(form: "กา-", .long),
            .finalConsonant(letters: "ก", sound: "-k", .dead),
        ])
    }

    func test_notes_leadingHo_isExplainedAsSilent() {
        XCTAssertEqual(notes("หนา"), [
            .silentHo(following: "น"),
            .vowelLength(form: "กา", .long),
            .noFinal(.long),
        ])
    }

    func test_notes_smoothCluster_andUnwrittenVowel() {
        XCTAssertEqual(notes("กลม"), [
            .cluster(letters: "กล", classLetter: "ก"),
            .consonantClass(letter: "ก", .mid),
            .unwrittenVowel,
            .finalConsonant(letters: "ม", sound: "-m", .live),
        ])
    }

    func test_notes_irregularCluster_andVowelWithEnding() {
        XCTAssertEqual(notes("ทราย"), [
            .irregularCluster(letters: "ทร", classLetter: "ท"),
            .consonantClass(letter: "ท", .low),
            .vowelWithEnding(form: "กาย"),
        ])
    }

    /// A marked syllable states the mark, not the vowel length or the ending
    func test_notes_markedSyllable() {
        XCTAssertEqual(notes("ข้าว"), [
            .consonantClass(letter: "ข", .high),
            .toneMark("้"),
            .vowelWithEnding(form: "กาว"),
        ])
        XCTAssertEqual(notes("เล่น"), [
            .consonantClass(letter: "ล", .low),
            .toneMark("่"),
        ])
    }

    func test_notes_shortOpenSyllable_isDead() {
        XCTAssertEqual(notes("คะ"), [
            .consonantClass(letter: "ค", .low),
            .vowelLength(form: "กะ", .short),
            .noFinal(.short),
        ])
    }

    func test_notes_lengthTheSpellingDoesNotShow_isNotGuessed() {
        XCTAssertEqual(notes("เลิก"), [
            .consonantClass(letter: "ล", .low),
            .vowelLengthNotShown(form: "เกิ-"),
            .finalConsonant(letters: "ก", sound: "-k", .dead),
        ])
    }

    func test_notes_silencedLetter() {
        XCTAssertEqual(notes("สัตว์"), [
            .consonantClass(letter: "ส", .high),
            .vowelLength(form: "กั-", .short),
            .finalConsonant(letters: "ต", sound: "-t", .dead),
            .silenced(letters: "ว"),
        ])
        XCTAssertEqual(notes("สิทธิ์").last, .silenced(letters: "ธิ"))
    }

    /// ควบ reads as ค + ◌ว◌ + บ, and also as คว + unwritten vowel + บ
    func test_notes_spellingWithAnotherReading_saysSoFirst() {
        XCTAssertEqual(notes("ควบ").first, .otherReading)
        XCTAssertFalse(notes("กาย").contains(.otherReading))
    }

    func test_notes_areEmptyWhenTheTextIsNotRead() {
        XCTAssertEqual(notes(""), [])
        XCTAssertEqual(notes("ขนม"), [])
    }

    /// Notes describe the text: a hand-set class does not rewrite them
    func test_notes_ignoreHandSetFacts() {
        var finder = finder(text: "นา")
        finder.chosenClass = .high
        XCTAssertEqual(resolve(finder).readingNotes.first, .consonantClass(letter: "น", .low))
    }

    func test_midOnlyMarkOnAnotherClass_givesANoticeAndNoTone() {
        var finder = ToneFinder()
        finder.chosenClass = .low
        finder.chosenMark = .mark("๊")
        let resolution = resolve(finder)
        XCTAssertNil(resolution.derivation)
        XCTAssertEqual(resolution.notice, .markNotUsedWithClass)
    }
}

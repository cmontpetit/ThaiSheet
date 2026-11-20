//
//  ReferenceBookScopeTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

/// The chapter scope as the Reference tab applies it.
@MainActor
final class ReferenceBookScopeTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settings: FlashcardSettings!
    private var data: ThaiDataStore!

    override func setUp() {
        super.setUp()
        suiteName = "ReferenceBookScopeTests_\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settings = FlashcardSettings(defaults: defaults)
        data = ThaiDataStore()
    }

    override func tearDown() {
        data = nil
        settings = nil
        defaults = nil
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        suiteName = nil
        super.tearDown()
    }

    private func scope(_ chapter: BookChapter?, notInBook: Bool = false) -> ReferenceBookScope {
        settings.bookProgress = chapter
        settings.showNotInBook = notInBook
        return ReferenceBookScope(settings: settings, map: data.bookChapters)
    }

    private func vowel(_ id: String) throws -> Vowel {
        try XCTUnwrap(data.vowels.first { $0.id == id })
    }

    private func consonant(_ character: String) throws -> Consonant {
        try XCTUnwrap(data.consonants.first { $0.character == character })
    }

    // MARK: - Off / inactive

    func test_off_showsEverything() throws {
        let off = scope(nil)
        XCTAssertFalse(off.isActive)
        XCTAssertTrue(data.consonants.allSatisfy { off.includes($0) })
        XCTAssertTrue(data.clusters.allSatisfy { off.includes($0) })
        XCTAssertTrue(data.toneRules.allSatisfy { off.includes($0) })
        XCTAssertTrue(data.toneMarks.allSatisfy { off.includes($0) })
        XCTAssertTrue(data.vowels.allSatisfy { off.hiddenForms(of: $0).isEmpty && off.showsRow($0) })
    }

    /// What the browser uses while searching: search includes all chapters.
    func test_inactive_showsEverything() throws {
        _ = scope(.day1)
        let searching = ReferenceBookScope.inactive
        XCTAssertTrue(searching.includes(try consonant("ข")))
        XCTAssertTrue(searching.hiddenForms(of: try vowel("a")).isEmpty)
    }

    func test_missingMap_showsEverything() throws {
        settings.bookProgress = .day1
        let noMap = ReferenceBookScope(settings: settings, map: nil)
        XCTAssertFalse(noMap.isActive)
        XCTAssertTrue(noMap.includes(try consonant("ข")))
    }

    // MARK: - Rows

    func test_day1_consonantsClustersTones() throws {
        let day1 = scope(.day1)
        XCTAssertEqual(data.consonants.filter { day1.includes($0) }.count, 7)
        XCTAssertTrue(day1.includes(try consonant("ง")))
        XCTAssertFalse(day1.includes(try consonant("ก")))
        XCTAssertFalse(data.clusters.contains { day1.includes($0) })
        XCTAssertFalse(data.toneRules.contains { day1.includes($0) })
        XCTAssertFalse(data.toneMarks.contains { day1.includes($0) })
    }

    func test_toneRuleRowsOnDay5_toneMarkRowsOnDay6() {
        let day5 = scope(.day5)
        XCTAssertTrue(data.toneRules.allSatisfy { day5.includes($0) })
        XCTAssertFalse(data.toneMarks.contains { day5.includes($0) })
        let day6 = scope(.day6)
        XCTAssertTrue(data.toneMarks.allSatisfy { day6.includes($0) })
    }

    func test_notTaughtInBook_followsToggle() throws {
        XCTAssertFalse(scope(.lastDay).includes(try consonant("ฃ")))
        XCTAssertTrue(scope(.lastDay, notInBook: true).includes(try consonant("ฃ")))
    }

    // MARK: - Vowel forms

    /// Day 1 teaches the long forms of `a`; its short forms arrive on Day 3.
    func test_vowelRow_hidesFormsNotYetTaught() throws {
        let a = try vowel("a")
        let day1 = scope(.day1)
        XCTAssertEqual(day1.hiddenForms(of: a), [.shortClosed, .shortOpen])
        XCTAssertTrue(day1.showsRow(a))
        XCTAssertTrue(day1.showsRow(a, duration: .long))
        XCTAssertFalse(day1.showsRow(a, duration: .short), "the Short chip shows no form of it yet")
        XCTAssertTrue(scope(.day3).hiddenForms(of: a).isEmpty)
    }

    func test_vowelRow_withNoTaughtFormIsDropped() throws {
        let ia = try vowel("ia")
        XCTAssertFalse(scope(.day5).showsRow(ia))
        XCTAssertTrue(scope(.day6).showsRow(ia))
        XCTAssertEqual(scope(.day6).hiddenForms(of: ia), [.shortOpen])
    }

    /// เกิ- is taught only as long; its short slot stays hidden, but its card is in scope.
    func test_sharedForm_longSlotVisible_cardInScope() throws {
        let oe = try vowel("oe")
        let day5 = scope(.day5)
        XCTAssertEqual(day5.hiddenForms(of: oe), [.shortClosed, .shortOpen])
        XCTAssertTrue(day5.includesVowelForm(oe, text: "เกิ-"))
        XCTAssertFalse(scope(.day4).includesVowelForm(oe, text: "เกิ-"))
    }

    // MARK: - Tone-mark empty columns

    /// ๊ and ๋ have no low or high class entry. Those empty columns are not
    /// content, so "Not taught in the book" must not reveal them before Day 6.
    func test_toneMarks_emptyColumnsDoNotQualifyRow() {
        let day5 = scope(.day5, notInBook: true)
        XCTAssertFalse(data.toneMarks.contains { day5.includes($0) })
        XCTAssertTrue(data.toneMarks.contains { $0.classEntries.contains { $0.tone == nil } },
                      "the data still has empty columns, so this test means something")
        XCTAssertEqual(data.toneMarks.filter { scope(.day6).includes($0) }.count, data.toneMarks.count)
    }

    // MARK: - Explicit jumps reveal a row

    func test_reveal_toneRuleAndToneMark_beyondChapter() throws {
        let day4 = scope(.day4)
        let rule = try XCTUnwrap(data.toneRules.first)
        XCTAssertFalse(day4.includes(rule))
        XCTAssertTrue(day4.revealing([.toneRule: rule.id]).includes(rule))
        XCTAssertFalse(day4.revealing([.toneRule: rule.id]).includes(try XCTUnwrap(data.toneRules.last)),
                       "only the requested row")

        let mark = try XCTUnwrap(data.toneMarks.first)
        let entry = try XCTUnwrap(mark.classEntries.first { $0.tone != nil })
        XCTAssertFalse(scope(.day5).includes(mark))
        XCTAssertTrue(scope(.day5).revealing([.toneMark: entry.soundKey]).includes(mark))
        XCTAssertEqual(settings.bookProgress, .day5, "revealing never changes the saved chapter")
    }

    func test_reveal_consonantClusterAndVowelForm() throws {
        let day1 = scope(.day1)
        XCTAssertTrue(day1.revealing([.consonant: "ข"]).includes(try consonant("ข")))
        let cluster = try XCTUnwrap(data.clusters.first { $0.id == "กร:initial" })
        XCTAssertTrue(day1.revealing([.cluster: "กร:initial"]).includes(cluster))
        XCTAssertEqual(day1.revealing([.vowel: "กะ"]).hiddenForms(of: try vowel("a")), [.shortClosed])
    }

    /// เกิ- fills two slots. On Day 5 its long slot is visible, so a jump needs
    /// no exception and the short slot stays hidden. On Day 4 neither is
    /// visible, so the jump reveals only the card's own (short) slot.
    func test_reveal_sharedForm_onlyWhenNeeded_onlyOneSlot() throws {
        let oe = try vowel("oe")
        XCTAssertEqual(scope(.day5).revealing([.vowel: "เกิ-"]).hiddenForms(of: oe), [.shortClosed, .shortOpen])
        XCTAssertEqual(scope(.day4).revealing([.vowel: "เกิ-"]).hiddenForms(of: oe), [.shortOpen, .longClosed, .longOpen])
    }

    // MARK: - Vowel Sound cell candidates

    /// Day 8, Short chip: the uea row shows only เกือะ, so the Sound cell may
    /// use only it, never the long example.
    func test_soundCandidates_onlyDisplayedForms() throws {
        let uea = try vowel("uea")
        let hidden = scope(.day8).hiddenForms(of: uea)
        let short = VowelRowView.soundCandidates(for: uea, visibleDuration: .short, hiddenForms: hidden)
        XCTAssertEqual(short.map(\.text), ["เกือะ"])
        XCTAssertEqual(short.map(\.formType), [.shortOpen])

        let both = VowelRowView.soundCandidates(for: uea, visibleDuration: nil, hiddenForms: hidden)
        XCTAssertEqual(both.first?.formType, .longClosed)

        let day5Hidden = scope(.day5).hiddenForms(of: try vowel("a"))
        let aLong = VowelRowView.soundCandidates(for: try vowel("a"), visibleDuration: nil, hiddenForms: [.shortClosed, .shortOpen])
        XCTAssertTrue(day5Hidden.isEmpty)
        XCTAssertFalse(aLong.contains { $0.formType.duration == .short })
    }

    // MARK: - Practice outside chapter

    func test_practiceOutsideChapter_perItem() throws {
        let day1 = scope(.day1)
        XCTAssertTrue(day1.includes(.consonant("ง"), data: data))
        XCTAssertFalse(day1.includes(.consonant("ข"), data: data))

        let day5 = scope(.day5)
        XCTAssertTrue(day5.includes(.vowel(id: "oe", variant: .shortClosed, text: "เกิ-"), data: data),
                      "the card for เกิ- is in scope through its long slot")
        XCTAssertFalse(day5.includes(.vowel(id: "ia", variant: .longOpen, text: "เกีย"), data: data))
        XCTAssertFalse(day5.includes(.cluster("กร:initial"), data: data))

        let mark = try XCTUnwrap(data.toneMarks.first)
        let entry = try XCTUnwrap(mark.classEntries.first)
        XCTAssertFalse(day5.includes(.toneMark(id: mark.id, soundKey: entry.soundKey), data: data))
        XCTAssertTrue(scope(.day6).includes(.toneMark(id: mark.id, soundKey: entry.soundKey), data: data))
    }
}

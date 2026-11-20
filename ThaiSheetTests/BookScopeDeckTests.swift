//
//  BookScopeDeckTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

/// Fails only the chapter mapping, so the catalogs load and the scope has no map.
private struct MissingBookMapProvider: ResourceProviding {
    func data(forResource resource: String) throws -> Data {
        if resource == BookChapterMap.resource {
            throw DatasetLoadError(resource: resource, failure: .resourceMissing)
        }
        return try BundleResourceProvider().data(forResource: resource)
    }
}

/// Keeps short-lived models alive for the whole run (see the Swift 6.2
/// deinit note in CLAUDE.md "Testing Gotchas").
private enum Retained {
    nonisolated(unsafe) static var objects: [AnyObject] = []
}

/// The chapter scope applied to the flashcard deck, and the deck-based SRS cap.
@MainActor
final class BookScopeDeckTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settings: FlashcardSettings!
    private var manager: FlashcardManager!

    override func setUp() {
        super.setUp()
        suiteName = "BookScopeDeckTests_\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settings = FlashcardSettings(defaults: defaults)
        manager = makeManager(data: ThaiDataStore())
    }

    override func tearDown() {
        manager = nil
        settings = nil
        defaults = nil
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        suiteName = nil
        super.tearDown()
    }

    private func makeManager(data: ThaiDataStore) -> FlashcardManager {
        let manager = FlashcardManager(settings: settings, learningModel: LearningModel(store: defaults), data: data)
        manager.learningModel.advanceClockOnEachReview()
        Retained.objects.append(contentsOf: [data, manager] as [AnyObject])
        return manager
    }

    // MARK: - Helpers

    private func deckIDs(_ type: FlashcardType) -> Set<String> {
        Set(manager.filteredCards.filter { $0.type == type }.map(\.id))
    }

    private func vowelDisplays() -> Set<String> {
        Set(manager.filteredCards.compactMap { if case .vowel(let card) = $0 { card.display } else { nil } })
    }

    private func consonant(_ character: String) throws -> FlashcardItem {
        let consonant = try XCTUnwrap(manager.data.consonants.first { $0.character == character })
        return .consonant(consonant, includesName: settings.consonantNames)
    }

    private func vowelCard(_ display: String) throws -> FlashcardItem {
        .vowel(try XCTUnwrap(manager.data.vowelCards.first { $0.display == display }))
    }

    private func cluster(_ id: String) throws -> FlashcardItem {
        .cluster(try XCTUnwrap(manager.data.clusters.first { $0.id == id }))
    }

    // MARK: - Deck contents

    func test_off_deckIsUnchanged() {
        XCTAssertNil(settings.bookProgress)
        XCTAssertEqual(manager.filteredCards.count, manager.allCards.count)
    }

    func test_bookRomanizationAndChapterScopeAreIndependent() throws {
        let originalScheme = settings.romanization
        defer { settings.romanization = originalScheme }
        let unscoped = manager.filteredCards.map(\.id)
        manager.jumpToConsonant("ข")
        let originalCard = try XCTUnwrap(manager.currentCard?.id)
        let consonant = try XCTUnwrap(manager.data.consonants.first { $0.character == "ข" })

        settings.romanization = .readThaiIn10Days
        XCTAssertNil(settings.bookProgress)
        XCTAssertEqual(manager.filteredCards.map(\.id), unscoped)
        XCTAssertEqual(manager.currentCard?.id, originalCard)
        XCTAssertEqual(consonant.transcription.romanized, "kŏr kài")

        settings.bookProgress = .day1
        settings.showNotInBook = true
        manager.applyBookScopeChange()
        let scoped = manager.filteredCards.map(\.id)
        XCTAssertNotEqual(scoped, unscoped)
        XCTAssertEqual(settings.romanization, .readThaiIn10Days)
        XCTAssertEqual(consonant.transcription.romanized, "kŏr kài")

        settings.romanization = .learner
        XCTAssertEqual(settings.bookProgress, .day1)
        XCTAssertTrue(settings.showNotInBook)
        XCTAssertEqual(manager.filteredCards.map(\.id), scoped)
    }

    func test_day1_consonantsAreLowClass1_inBothNameModes() {
        settings.bookProgress = .day1
        let expected = ["ง", "ม", "น", "ร", "ล", "ย", "ว"]
        XCTAssertEqual(deckIDs(.consonant), Set(expected.map { FlashcardType.consonantCardId(for: $0, includesName: true) }))
        settings.consonantNames = false
        XCTAssertEqual(deckIDs(.consonant), Set(expected.map { FlashcardType.consonantCardId(for: $0, includesName: false) }))
    }

    func test_day1_vowelsAreLongForms_noTonesOrClusters() {
        settings.bookProgress = .day1
        let displays = vowelDisplays()
        XCTAssertTrue(displays.isSuperset(of: ["กา", "กา-", "โก", "กอ", "กาย", "กาว"]))
        XCTAssertFalse(displays.contains("กะ"), "short vowels arrive on Day 3")
        XCTAssertFalse(displays.contains("กำ"), "taught on Day 2")
        XCTAssertTrue(deckIDs(.toneRule).isEmpty)
        XCTAssertTrue(deckIDs(.toneMark).isEmpty)
        XCTAssertTrue(deckIDs(.cluster).isEmpty)
    }

    func test_toneRulesFromDay5_toneMarksFromDay6() {
        settings.bookProgress = .day4
        XCTAssertTrue(deckIDs(.toneRule).isEmpty)
        settings.bookProgress = .day5
        XCTAssertEqual(deckIDs(.toneRule).count, manager.data.toneRuleCards.count)
        XCTAssertTrue(deckIDs(.toneMark).isEmpty)
        settings.bookProgress = .day6
        XCTAssertEqual(deckIDs(.toneMark).count, 8)
    }

    func test_silentHClustersFromDay4() {
        settings.bookProgress = .day4
        let ids = deckIDs(.cluster)
        XCTAssertEqual(ids.count, 7)
        XCTAssertTrue(ids.contains(FlashcardType.cluster.cardId(for: "หน:initial")))
        XCTAssertFalse(ids.contains(FlashcardType.cluster.cardId(for: "หญ:initial")), "ญ arrives on Day 7")
    }

    /// เกิ- is one card for two slots; it is eligible once its long slot is (Day 5).
    func test_sharedForm_eligibleWithItsEarlierSlot() {
        settings.bookProgress = .day4
        XCTAssertFalse(vowelDisplays().contains("เกิ-"))
        settings.bookProgress = .day5
        XCTAssertTrue(vowelDisplays().contains("เกิ-"))
    }

    /// `uay` is looked up by slot (Long:Closed, Day 5); its card keeps its progress key.
    func test_uay_eligibleOnDay5_keepsProgressKey() throws {
        settings.bookProgress = .day4
        XCTAssertFalse(vowelDisplays().contains("กวย"))
        settings.bookProgress = .day5
        XCTAssertTrue(vowelDisplays().contains("กวย"))
        XCTAssertEqual(try vowelCard("กวย").id, FlashcardType.vowel.cardId(for: "uay:Short:Closed"))
    }

    func test_notTaughtInBook_followsToggle() {
        settings.bookProgress = .lastDay
        let kho = FlashcardType.consonantCardId(for: "ฃ", includesName: true)
        XCTAssertFalse(deckIDs(.consonant).contains(kho))
        XCTAssertFalse(vowelDisplays().contains("โกย"))
        settings.showNotInBook = true
        XCTAssertTrue(deckIDs(.consonant).contains(kho))
        XCTAssertTrue(vowelDisplays().contains("โกย"))
    }

    func test_lastDayWithToggle_isTheWholeDeck() {
        settings.bookProgress = .lastDay
        settings.showNotInBook = true
        XCTAssertEqual(manager.filteredCards.count, manager.allCards.count)
    }

    func test_scopeStacksWithFilters() {
        settings.bookProgress = .day4
        settings.highConsonants = false
        XCTAssertEqual(deckIDs(.consonant).count, 21)
    }

    func test_missingMap_scopeIsOff() {
        let data = ThaiDataStore(provider: MissingBookMapProvider())
        XCTAssertNil(data.bookChapters)
        XCTAssertTrue(data.isLoaded, "the mapping is not a catalog")
        manager = makeManager(data: data)
        settings.bookProgress = .day1
        XCTAssertEqual(manager.filteredCards.count, manager.allCards.count)
    }

    // MARK: - Deck-based SRS cap (also covers the cases the old settings-based cap did)

    func test_cap_fullDeck_capsNothing() throws {
        for card in manager.allCards {
            XCTAssertFalse(manager.isPartialTesting(card), card.id)
        }
    }

    func test_cap_singleConsonantClassFilter() throws {
        settings.midConsonants = false
        settings.lowConsonants = false
        XCTAssertTrue(manager.isPartialTesting(try consonant("ข")))
        settings.midConsonants = true
        XCTAssertFalse(manager.isPartialTesting(try consonant("ข")))
    }

    func test_cap_singleVowelDurationFilter_onlyCardsAskingDuration() throws {
        settings.shortVowels = false
        XCTAssertTrue(manager.isPartialTesting(try vowelCard("กา")))
        XCTAssertTrue(manager.isPartialTesting(try vowelCard("เกิ-")), "accepts both durations, including the given-away one")
        XCTAssertFalse(manager.isPartialTesting(try vowelCard("กวย")), "asks no duration or form question")
    }

    func test_cap_singleToneRuleClassFilter() throws {
        settings.midToneRules = false
        settings.lowToneRules = false
        let card = try XCTUnwrap(manager.filteredCards.first { $0.type == .toneRule })
        XCTAssertTrue(manager.isPartialTesting(card))
        settings.lowToneRules = true
        XCTAssertFalse(manager.isPartialTesting(card), "High + Low rules vary in class, duration, and ending")
    }

    /// Every High and Mid rule has vowel duration "Any", so that pair of
    /// filters gives the duration away even though it leaves two classes.
    func test_cap_highAndMidToneRules_durationGivenAway() throws {
        settings.lowToneRules = false
        let card = try XCTUnwrap(manager.filteredCards.first { $0.type == .toneRule })
        XCTAssertTrue(manager.isPartialTesting(card))
    }

    /// D11: the cap also applies to ordinary filters. Only silent ห clusters
    /// leaves the cluster type always "silent".
    func test_cap_silentClustersOnly() throws {
        settings.smoothClusters = false
        settings.irregularClusters = false
        XCTAssertTrue(manager.isPartialTesting(try cluster("หน:initial")))
    }

    func test_cap_day1_classAndDurationGivenAway() throws {
        settings.bookProgress = .day1
        XCTAssertTrue(manager.isPartialTesting(try consonant("ม")))
        XCTAssertTrue(manager.isPartialTesting(try vowelCard("กา")))
        settings.bookProgress = .day4
        XCTAssertFalse(manager.isPartialTesting(try consonant("ม")))
    }

    /// A card opened from Reference outside the deck is capped only by answers it accepts.
    func test_cap_oneOffCard_notCappedByAnswerItDoesNotAccept() throws {
        settings.bookProgress = .day1
        XCTAssertFalse(manager.isPartialTesting(try consonant("ข")), "deck is all low class, ข is high")
    }

    func test_cap_emptyComparisonGroup_neverCaps() throws {
        settings.bookProgress = .day1
        XCTAssertTrue(deckIDs(.cluster).isEmpty)
        XCTAssertFalse(manager.isPartialTesting(try cluster("หน:initial")))
    }

    // MARK: - Scope changes and practice outside the chapter

    func test_scopeChange_clearsIneligibleOverride_keepsEligibleOne() {
        settings.bookProgress = .day1
        manager.applyBookScopeChange()
        manager.jumpToConsonant("ข")
        XCTAssertEqual(manager.currentCard?.id, FlashcardType.consonantCardId(for: "ข", includesName: true))

        settings.bookProgress = .day4
        manager.applyBookScopeChange()
        XCTAssertEqual(manager.currentCard?.id, FlashcardType.consonantCardId(for: "ข", includesName: true),
                       "ข is in the Day 4 deck, so the opened card stays")

        settings.bookProgress = .day3
        manager.applyBookScopeChange()
        XCTAssertNotEqual(manager.currentCard?.id, FlashcardType.consonantCardId(for: "ข", includesName: true))
        XCTAssertTrue(manager.filteredCards.contains { $0.id == manager.currentCard?.id })
    }

    /// D10: practice outside the chapter is graded normally (a wrong answer
    /// drops two stages), then Next returns to the scoped deck.
    func test_practiceOutsideChapter_gradedNormally_thenBackToDeck() throws {
        settings.bookProgress = .day1
        manager.applyBookScopeChange()
        manager.jumpToConsonant("ข")
        let card = try XCTUnwrap(manager.currentCard)
        XCTAssertFalse(manager.filteredCards.contains { $0.id == card.id }, "ข is outside Day 1")
        XCTAssertFalse(manager.isPartialTesting(card))

        for _ in 0..<3 {
            manager.learningModel.recordResult(for: card, correct: true, fullTesting: !manager.isPartialTesting(card))
        }
        XCTAssertEqual(manager.learningModel.srsStage(for: card), .apprentice1)

        manager.learningModel.recordResult(for: card, correct: false, fullTesting: !manager.isPartialTesting(card))
        XCTAssertEqual(manager.learningModel.srsStage(for: card), .learning1, "Apprentice 1 drops two stages")
        XCTAssertEqual(manager.learningModel.getProgress(forId: card.id).incorrectCount, 1)

        manager.nextCard()
        XCTAssertTrue(manager.filteredCards.contains { $0.id == manager.currentCard?.id })
    }

    // MARK: - Shared vowel form presentation

    private func deckVowelCard(_ display: String) throws -> VowelCard {
        let item = try XCTUnwrap(manager.filteredCards.first {
            if case .vowel(let card) = $0 { card.display == display } else { false }
        })
        guard case .vowel(let card) = item else { throw XCTSkip("not a vowel") }
        return card
    }

    /// On Day 5 only เกิ-'s long slot is in scope: the card presents that slot's
    /// example (เดิน), keeps its progress id, and still accepts both durations.
    func test_sharedForm_presentsInScopeSlot() throws {
        let original = try deckVowelCard("เกิ-")
        XCTAssertEqual(original.shownDuration, original.duration)
        XCTAssertEqual(original.prompt, "เงิน")

        settings.bookProgress = .day5
        let scoped = try deckVowelCard("เกิ-")
        XCTAssertEqual(scoped.shownDuration, .long)
        XCTAssertEqual(scoped.pronunciationWord?.word, "เดิน")
        XCTAssertEqual(scoped.prompt, "เดิน")
        XCTAssertEqual(scoped.id, original.id)
        XCTAssertEqual(scoped.duration, original.duration)
        XCTAssertEqual(FlashcardItem.vowel(scoped).fixedAnswerQuestions[.vowelDuration], ["Short", "Long"])
        XCTAssertEqual(scoped.alternativeDuration, .short)
    }

    private var currentVowelWord: String? {
        guard case .vowel(let card) = manager.currentCard else { return nil }
        return card.pronunciationWord?.word
    }

    /// Opening เกิ- from Reference lands on the deck's copy, in both selection modes.
    func test_sharedForm_jumpFromReference_presentsInScopeSlot() {
        settings.bookProgress = .day5
        manager.applyBookScopeChange()
        for smart in [false, true] {
            settings.useIntelligentSelection = smart
            manager.jumpToVowel("เกิ-")
            XCTAssertEqual(currentVowelWord, "เดิน", "smart mode: \(smart)")
        }
    }

    /// A one-off เกิ- opened on Day 4 switches to the in-scope slot when Day 5 makes it eligible.
    func test_sharedForm_overrideBecomingEligible_presentsInScopeSlot() throws {
        settings.bookProgress = .day4
        manager.applyBookScopeChange()
        manager.jumpToVowel("เกิ-")
        let openedID = try XCTUnwrap(manager.currentCard?.id)
        XCTAssertEqual(currentVowelWord, "เงิน", "outside the deck it presents its own (short) slot")

        settings.bookProgress = .day5
        manager.applyBookScopeChange()
        XCTAssertEqual(manager.currentCard?.id, openedID)
        XCTAssertEqual(currentVowelWord, "เดิน")
    }

    /// In chapter scope but excluded by Filters: the one-off card still presents the in-scope slot.
    func test_sharedForm_overrideExcludedByFilters_presentsInScopeSlot() {
        settings.bookProgress = .day5
        settings.vowelsEnabled = false
        manager.applyBookScopeChange()
        XCTAssertFalse(vowelDisplays().contains("เกิ-"))
        manager.jumpToVowel("เกิ-")
        XCTAssertEqual(currentVowelWord, "เดิน")
    }

    // MARK: - Shared form with the duration filter

    private func sharedFormWord() -> String? {
        manager.filteredCards.lazy.compactMap { item -> String? in
            guard case .vowel(let card) = item, card.display == "เกิ-" else { return nil }
            return card.pronunciationWord?.word
        }.first
    }

    /// One slot decides the duration filter, the chapter, and the example.
    func test_sharedForm_day5_longOnly_presentsLongSlot() {
        settings.bookProgress = .day5
        settings.shortVowels = false
        XCTAssertEqual(sharedFormWord(), "เดิน", "its long slot passes both the filter and the chapter")
    }

    func test_sharedForm_day5_shortOnly_isExcluded() {
        settings.bookProgress = .day5
        settings.longVowels = false
        XCTAssertNil(sharedFormWord(), "its short slot is not taught; its long slot is filtered out")
    }

    func test_sharedForm_day5_shortOnlyWithNotTaught_presentsShortSlot() {
        settings.bookProgress = .day5
        settings.longVowels = false
        settings.showNotInBook = true
        XCTAssertEqual(sharedFormWord(), "เงิน")
    }

    func test_sharedForm_day5_bothDurations_presentsLongSlot() {
        settings.bookProgress = .day5
        XCTAssertEqual(sharedFormWord(), "เดิน")
    }

    /// Without a chapter, the duration filter alone picks the slot. Before,
    /// Long only dropped the card because only its short slot was checked.
    func test_sharedForm_off_followsDurationFilter() {
        XCTAssertEqual(sharedFormWord(), "เงิน", "both durations: the card's own (short) slot")
        settings.shortVowels = false
        XCTAssertEqual(sharedFormWord(), "เดิน")
        settings.shortVowels = true
        settings.longVowels = false
        XCTAssertEqual(sharedFormWord(), "เงิน")
    }

    /// The progress id and accepted durations never follow the presented slot.
    func test_sharedForm_presentedSlot_keepsIdAndAnswers() throws {
        let original = try vowelCard("เกิ-")
        settings.shortVowels = false
        let item = try XCTUnwrap(manager.filteredCards.first { $0.id == original.id })
        XCTAssertEqual(item.fixedAnswerQuestions[.vowelDuration], ["Short", "Long"])
    }

    func test_sharedForm_ownSlotInScope_presentsOwnSlot() throws {
        settings.bookProgress = .day5
        settings.showNotInBook = true
        let card = try deckVowelCard("เกิ-")
        XCTAssertEqual(card.shownDuration, card.duration)
    }
}

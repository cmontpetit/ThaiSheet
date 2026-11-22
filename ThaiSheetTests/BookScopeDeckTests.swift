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

    // MARK: - Specific days

    /// Every card's placements in the map: a vowel card counts each slot it covers.
    private func placements(of item: FlashcardItem, map: BookChapterMap) -> [BookPlacement?] {
        switch item {
        case .consonant(let consonant, _): return [map.placement(of: consonant)]
        case .cluster(let cluster): return [map.placement(of: cluster)]
        case .toneMark(let card): return [map.placement(of: card)]
        case .toneRule(let card): return [map.placement(of: card.rule, sample: card.sample)]
        case .vowel(let card):
            let durations: [VowelCard.VowelDuration] = card.acceptsBothDurations ? [.short, .long] : [card.duration]
            let forms: [VowelCard.VowelFormType] = card.coversClosedForm ? [.open, .closed] : [card.form]
            return durations.flatMap { duration in forms.map { map.placement(of: card.vowel, duration: duration, form: $0) } }
        }
    }

    private func assertDeckMatches(_ chapters: Set<BookChapter>, file: StaticString = #filePath, line: UInt = #line) throws {
        let map = try XCTUnwrap(manager.data.bookChapters)
        let deck = Set(manager.filteredCards.map(\.id))
        XCTAssertFalse(deck.isEmpty, file: file, line: line)
        for item in manager.allCards {
            let introduced = placements(of: item, map: map).contains {
                if case .chapter(let chapter) = $0 { chapters.contains(chapter) } else { false }
            }
            XCTAssertEqual(deck.contains(item.id), introduced, item.id, file: file, line: line)
        }
    }

    func test_singleDay_deckIsThatDaysMaterial() throws {
        settings.bookSelection = .days([.day5])
        manager.syncDeck()
        try assertDeckMatches([.day5])
        XCTAssertFalse(deckIDs(.consonant).contains(try consonant("ง").id), "Day 1 is not in Day 5 alone")
    }

    func test_nonConsecutiveDays_deckIsThoseDaysMaterial() throws {
        settings.bookSelection = .days([.day2, .day4])
        manager.syncDeck()
        try assertDeckMatches([.day2, .day4])
    }

    func test_throughDay5_includesEarlierDays_dayFiveAloneDoesNot() throws {
        settings.bookSelection = .through(.day5)
        manager.syncDeck()
        let through = Set(manager.filteredCards.map(\.id))
        settings.bookSelection = .days([.day5])
        manager.syncDeck()
        let alone = Set(manager.filteredCards.map(\.id))
        XCTAssertTrue(alone.isSubset(of: through))
        XCTAssertTrue(through.contains(try consonant("ง").id))
        XCTAssertFalse(alone.contains(try consonant("ง").id))
    }

    func test_daySelectionChange_isADeckChange() {
        settings.bookSelection = .days([.day2])
        XCTAssertTrue(manager.syncDeck())
        settings.bookSelection = .days([.day2, .day4])
        XCTAssertTrue(manager.syncDeck())
        XCTAssertFalse(manager.syncDeck(), "Applied once")
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
        manager.syncDeck()
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
        manager.syncDeck()
        let expected = ["ง", "ม", "น", "ร", "ล", "ย", "ว"]
        XCTAssertEqual(deckIDs(.consonant), Set(expected.map { FlashcardType.consonantCardId(for: $0, includesName: true) }))
        settings.consonantNames = false
        manager.syncDeck()
        XCTAssertEqual(deckIDs(.consonant), Set(expected.map { FlashcardType.consonantCardId(for: $0, includesName: false) }))
    }

    func test_day1_vowelsAreLongForms_noTonesOrClusters() {
        settings.bookProgress = .day1
        manager.syncDeck()
        let displays = vowelDisplays()
        XCTAssertTrue(displays.isSuperset(of: ["กา", "โก", "กอ", "กาย", "กาว"]), "กา- is part of the กา card")
        XCTAssertFalse(displays.contains("กะ"), "short vowels arrive on Day 3")
        XCTAssertFalse(displays.contains("กำ"), "taught on Day 2")
        XCTAssertTrue(deckIDs(.toneRule).isEmpty)
        XCTAssertTrue(deckIDs(.toneMark).isEmpty)
        XCTAssertTrue(deckIDs(.cluster).isEmpty)
    }

    func test_toneRulesFromDay5_toneMarksFromDay6() {
        settings.bookProgress = .day4
        manager.syncDeck()
        XCTAssertTrue(deckIDs(.toneRule).isEmpty)
        settings.bookProgress = .day5
        manager.syncDeck()
        XCTAssertEqual(deckIDs(.toneRule).count, manager.data.toneRuleCards.count)
        XCTAssertTrue(deckIDs(.toneMark).isEmpty)
        settings.bookProgress = .day6
        manager.syncDeck()
        XCTAssertEqual(deckIDs(.toneMark).count, 8)
    }

    func test_silentHClustersFromDay4() {
        settings.bookProgress = .day4
        manager.syncDeck()
        let ids = deckIDs(.cluster)
        XCTAssertEqual(ids.count, 7)
        XCTAssertTrue(ids.contains(FlashcardType.cluster.cardId(for: "หน:initial")))
        XCTAssertFalse(ids.contains(FlashcardType.cluster.cardId(for: "หญ:initial")), "ญ arrives on Day 7")
    }

    /// เกิ- is one card for two slots; it is eligible once its long slot is (Day 5).
    func test_sharedForm_eligibleWithItsEarlierSlot() {
        settings.bookProgress = .day4
        manager.syncDeck()
        XCTAssertFalse(vowelDisplays().contains("เกิ-"))
        settings.bookProgress = .day5
        manager.syncDeck()
        XCTAssertTrue(vowelDisplays().contains("เกิ-"))
    }

    /// `uay` is looked up by slot (Long:Closed, Day 5); its card keeps its progress key.
    func test_uay_eligibleOnDay5_keepsProgressKey() throws {
        settings.bookProgress = .day4
        manager.syncDeck()
        XCTAssertFalse(vowelDisplays().contains("กวย"))
        settings.bookProgress = .day5
        manager.syncDeck()
        XCTAssertTrue(vowelDisplays().contains("กวย"))
        XCTAssertEqual(try vowelCard("กวย").id, FlashcardType.vowel.cardId(for: "uay:Short:Closed"))
    }

    func test_notTaughtInBook_followsToggle() {
        settings.bookProgress = .lastDay
        manager.syncDeck()
        let kho = FlashcardType.consonantCardId(for: "ฃ", includesName: true)
        XCTAssertFalse(deckIDs(.consonant).contains(kho))
        XCTAssertFalse(vowelDisplays().contains("โกย"))
        settings.showNotInBook = true
        manager.syncDeck()
        XCTAssertTrue(deckIDs(.consonant).contains(kho))
        XCTAssertTrue(vowelDisplays().contains("โกย"))
    }

    func test_lastDayWithToggle_isTheWholeDeck() {
        settings.bookProgress = .lastDay
        settings.showNotInBook = true
        manager.syncDeck()
        XCTAssertEqual(manager.filteredCards.count, manager.allCards.count)
    }

    func test_scopeStacksWithFilters() {
        settings.bookProgress = .day4
        settings.highConsonants = false
        manager.syncDeck()
        XCTAssertEqual(deckIDs(.consonant).count, 21)
    }

    func test_missingMap_scopeIsOff() {
        let data = ThaiDataStore(provider: MissingBookMapProvider())
        XCTAssertNil(data.bookChapters)
        XCTAssertTrue(data.isLoaded, "the mapping is not a catalog")
        manager = makeManager(data: data)
        settings.bookProgress = .day1
        manager.syncDeck()
        XCTAssertEqual(manager.filteredCards.count, manager.allCards.count)
    }

    // MARK: - Deck-based SRS cap (also covers the cases the old settings-based cap did)

    func test_capAcceptedAnswers_matchQuizGradingAcrossCatalog() {
        for item in manager.allCards {
            let questions = item.fixedAnswerQuestions
            func check<Option: RawRepresentable>(
                _ question: CardQuestion, _ options: [Option], rejects: (Option) -> Bool
            ) where Option.RawValue == String {
                let accepted = Set(options.filter { !rejects($0) }.map(\.rawValue))
                XCTAssertEqual(questions[question], accepted, "\(item.id) \(question)")
            }

            switch item {
            case .consonant(let consonant, _):
                check(.consonantClass, ConsonantClass.allCases) {
                    CardState(selectedClass: $0).hasError(for: consonant)
                }
            case .vowel(let card):
                if card.asksDuration {
                    check(.vowelDuration, VowelCard.VowelDuration.allCases) {
                        VowelCardState(selectedDuration: $0).hasError(for: card)
                    }
                } else {
                    XCTAssertNil(questions[.vowelDuration], item.id)
                }
                if card.asksForm {
                    check(.vowelForm, VowelCard.FormAnswer.allCases) {
                        VowelCardState(selectedForm: $0).hasError(for: card)
                    }
                } else {
                    XCTAssertNil(questions[.vowelForm], item.id)
                }
            case .toneMark(let card):
                check(.toneMarkClass, ToneMarkCard.ConsonantClassType.allCases) {
                    ToneMarkCardState(selectedClass: $0).hasError(for: card)
                }
            case .toneRule(let card):
                let classes: [String] = ["Low", "Mid", "High"].filter {
                    !ToneRuleCardState(selectedConsonantClass: $0).hasError(for: card)
                }
                let durations: [String] = ["Short", "Long", "Any"].filter {
                    !ToneRuleCardState(selectedVowelDuration: $0).hasError(for: card)
                }
                let endings: [String] = ["Live", "Dead"].filter {
                    !ToneRuleCardState(selectedEnd: $0).hasError(for: card)
                }
                XCTAssertEqual(questions[.toneRuleClass], Set(classes), item.id)
                XCTAssertEqual(questions[.toneRuleDuration], Set(durations), item.id)
                XCTAssertEqual(questions[.toneRuleEnding], Set(endings), item.id)
            case .cluster(let cluster):
                check(.clusterType, ClusterType.allCases) {
                    ClusterCardState(selectedType: $0).hasError(for: cluster)
                }
            }
        }
    }

    func test_cap_fullDeck_capsNothing() throws {
        for card in manager.allCards {
            XCTAssertFalse(manager.isPartialTesting(card), card.id)
        }
    }

    func test_cap_singleConsonantClassFilter() throws {
        settings.midConsonants = false
        settings.lowConsonants = false
        manager.syncDeck()
        XCTAssertTrue(manager.isPartialTesting(try consonant("ข")))
        settings.midConsonants = true
        manager.syncDeck()
        XCTAssertFalse(manager.isPartialTesting(try consonant("ข")))
    }

    func test_cap_singleVowelDurationFilter_onlyCardsAskingDuration() throws {
        settings.shortVowels = false
        manager.syncDeck()
        XCTAssertTrue(manager.isPartialTesting(try vowelCard("กา")))
        XCTAssertTrue(manager.isPartialTesting(try vowelCard("เกิ-")), "accepts both durations, including the given-away one")
        XCTAssertFalse(manager.isPartialTesting(try vowelCard("กวย")), "asks no duration or form question")
    }

    func test_cap_singleToneRuleClassFilter() throws {
        settings.midToneRules = false
        settings.lowToneRules = false
        manager.syncDeck()
        let card = try XCTUnwrap(manager.filteredCards.first { $0.type == .toneRule })
        XCTAssertTrue(manager.isPartialTesting(card))
        settings.lowToneRules = true
        manager.syncDeck()
        XCTAssertFalse(manager.isPartialTesting(card), "High + Low rules vary in class, duration, and ending")
    }

    /// Every High and Mid rule has vowel duration "Any", so that pair of
    /// filters gives the duration away even though it leaves two classes.
    func test_cap_highAndMidToneRules_durationGivenAway() throws {
        settings.lowToneRules = false
        manager.syncDeck()
        let card = try XCTUnwrap(manager.filteredCards.first { $0.type == .toneRule })
        XCTAssertTrue(manager.isPartialTesting(card))
    }

    /// D11: the cap also applies to ordinary filters. Only silent ห clusters
    /// leaves the cluster type always "silent".
    func test_cap_silentClustersOnly() throws {
        settings.smoothClusters = false
        settings.irregularClusters = false
        manager.syncDeck()
        XCTAssertTrue(manager.isPartialTesting(try cluster("หน:initial")))
    }

    func test_cap_day1_classAndDurationGivenAway() throws {
        settings.bookProgress = .day1
        manager.syncDeck()
        XCTAssertTrue(manager.isPartialTesting(try consonant("ม")))
        XCTAssertTrue(manager.isPartialTesting(try vowelCard("กา")))
        settings.bookProgress = .day4
        manager.syncDeck()
        XCTAssertFalse(manager.isPartialTesting(try consonant("ม")))
    }

    /// A card opened from Reference outside the deck is capped only by answers it accepts.
    func test_cap_oneOffCard_notCappedByAnswerItDoesNotAccept() throws {
        settings.bookProgress = .day1
        manager.syncDeck()
        XCTAssertFalse(manager.isPartialTesting(try consonant("ข")), "deck is all low class, ข is high")
    }

    func test_cap_emptyComparisonGroup_neverCaps() throws {
        settings.bookProgress = .day1
        manager.syncDeck()
        XCTAssertTrue(deckIDs(.cluster).isEmpty)
        XCTAssertFalse(manager.isPartialTesting(try cluster("หน:initial")))
    }

    // MARK: - Scope changes and practice outside the chapter

    func test_practicingCurrentDeckCard_startsNewAttempt() {
        let target = ReferenceItem.consonant("ค")
        manager.practice(target)
        let cardID = manager.currentCard?.id
        let attempt = manager.attempt

        _ = manager.filteredCards
        XCTAssertEqual(manager.attempt, attempt)

        manager.practice(target)
        XCTAssertEqual(manager.currentCard?.id, cardID)
        XCTAssertEqual(manager.attempt, attempt + 1)
    }

    func test_scopeChange_clearsIneligibleOverride_keepsEligibleOne() {
        settings.bookProgress = .day1
        manager.syncDeck()
        manager.jumpToConsonant("ข")
        XCTAssertEqual(manager.currentCard?.id, FlashcardType.consonantCardId(for: "ข", includesName: true))

        settings.bookProgress = .day4
        manager.syncDeck()
        XCTAssertEqual(manager.currentCard?.id, FlashcardType.consonantCardId(for: "ข", includesName: true),
                       "ข is in the Day 4 deck, so the opened card stays")

        settings.bookProgress = .day3
        manager.syncDeck()
        XCTAssertNotEqual(manager.currentCard?.id, FlashcardType.consonantCardId(for: "ข", includesName: true))
        XCTAssertTrue(manager.filteredCards.contains { $0.id == manager.currentCard?.id })
    }

    /// D10: practice outside the chapter is graded normally (a wrong answer
    /// drops two stages), then Next returns to the scoped deck.
    func test_practiceOutsideChapter_gradedNormally_thenBackToDeck() throws {
        settings.bookProgress = .day1
        manager.syncDeck()
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
        XCTAssertEqual(original.pronunciationWord?.word, "เงิน")
        XCTAssertEqual(original.prompt, original.bareForm, "The face shows the vowel, not the word")

        settings.bookProgress = .day5
        manager.syncDeck()
        let scoped = try deckVowelCard("เกิ-")
        XCTAssertEqual(scoped.shownDuration, .long)
        XCTAssertEqual(scoped.pronunciationWord?.word, "เดิน")
        XCTAssertEqual(scoped.revealedSamples.map(\.word.word), ["เดิน"])
        XCTAssertEqual(scoped.id, original.id)
        XCTAssertEqual(scoped.duration, original.duration)
        XCTAssertEqual(FlashcardItem.vowel(scoped).fixedAnswerQuestions[.vowelDuration], ["Short", "Long"])
        XCTAssertEqual(scoped.alternativeDuration, .short)
    }

    private var currentVowelWord: String? {
        guard case .vowel(let card) = manager.currentCard else { return nil }
        return card.pronunciationWord?.word
    }

    private func practiceSharedVowel(_ variant: VowelFormVariant) {
        manager.practice(.vowel(id: "oe", variant: variant, text: "เกิ-"))
    }

    /// Practice on ◌า- in Reference opens the merged ◌า card.
    func test_mergedClosedForm_jumpFromReference_opensTheMergedCard() {
        manager.practice(.vowel(id: "a", variant: .longClosed, text: "กา-"))
        guard case .vowel(let card) = manager.currentCard else { return XCTFail("No vowel card opened") }
        XCTAssertEqual(card.id, "a:Long:Open")
        XCTAssertTrue(card.coversClosedForm)
    }

    /// Switches the mode the way the Flashcards tab's observer does.
    private func select(_ mode: SelectionMode) {
        settings.selectionMode = mode
        manager.applySelectionModeChange()
    }

    /// Opening เกิ- from Reference lands on the deck's copy, in every selection mode.
    func test_sharedForm_jumpFromReference_presentsInScopeSlot() {
        settings.bookProgress = .day5
        manager.syncDeck()
        for mode in SelectionMode.allCases {
            select(mode)
            practiceSharedVowel(.shortClosed)
            XCTAssertEqual(currentVowelWord, "เดิน", "mode: \(mode)")
        }
    }

    /// In Shuffled the opened เกิ- is a one-off: it shows the in-scope reading,
    /// and dismissing it returns the round to the same card and position.
    func test_sharedForm_jumpFromReference_shuffled_restoresRoundPosition() throws {
        settings.bookProgress = .day5
        manager.syncDeck()
        select(.shuffled)
        manager.nextCard()
        let roundCard = try XCTUnwrap(manager.currentCard?.id)
        let position = try XCTUnwrap(manager.roundPosition)

        practiceSharedVowel(.shortClosed)
        XCTAssertEqual(currentVowelWord, "เดิน")
        XCTAssertNil(manager.roundPosition)

        manager.nextCard()
        XCTAssertEqual(manager.currentCard?.id, roundCard)
        XCTAssertEqual(manager.roundPosition, position)
    }

    /// A one-off เกิ- opened on Day 4 switches to the in-scope slot when Day 5 makes it eligible.
    func test_sharedForm_overrideBecomingEligible_presentsInScopeSlot() throws {
        for mode in SelectionMode.allCases {
            select(mode)
            settings.bookProgress = .day4
            manager.syncDeck()
            practiceSharedVowel(.shortClosed)
            let openedID = try XCTUnwrap(manager.currentCard?.id)
            let attempt = manager.attempt
            XCTAssertEqual(currentVowelWord, "เงิน", "outside the deck it presents its own (short) slot, mode: \(mode)")

            settings.bookProgress = .day5
            manager.syncDeck()
            XCTAssertEqual(manager.currentCard?.id, openedID, "mode: \(mode)")
            XCTAssertEqual(currentVowelWord, "เดิน", "mode: \(mode)")
            XCTAssertEqual(manager.attempt, attempt + 1, "mode: \(mode)")
            manager.nextCard()
        }
    }

    /// In chapter scope but excluded by Filters: the one-off card still presents the in-scope slot.
    func test_sharedForm_overrideExcludedByFilters_presentsInScopeSlot() {
        settings.bookProgress = .day5
        settings.vowelsEnabled = false
        manager.syncDeck()
        XCTAssertFalse(vowelDisplays().contains("เกิ-"))
        for mode in SelectionMode.allCases {
            select(mode)
            practiceSharedVowel(.shortClosed)
            XCTAssertEqual(currentVowelWord, "เดิน", "mode: \(mode)")
        }
    }

    func test_sharedForm_practiceUsesSelectedReadingAndKeepsSequentialPosition() throws {
        let cardID = try vowelCard("เกิ-").id
        let index = try XCTUnwrap(manager.filteredCards.firstIndex { $0.id == cardID })

        practiceSharedVowel(.shortClosed)
        XCTAssertEqual(currentVowelWord, "เงิน")
        XCTAssertEqual(manager.currentCard?.id, cardID)
        practiceSharedVowel(.longClosed)
        XCTAssertEqual(currentVowelWord, "เดิน")
        XCTAssertEqual(manager.currentCard?.id, cardID)

        manager.nextCard()
        XCTAssertEqual(manager.currentCard?.id, manager.filteredCards[index + 1].id)
    }

    func test_sharedForm_practiceOutsideFiltersStartsNewAttemptEachTime() throws {
        settings.vowelsEnabled = false
        manager.syncDeck()
        let cardID = try vowelCard("เกิ-").id
        let initialAttempt = manager.attempt

        practiceSharedVowel(.longClosed)
        XCTAssertEqual(currentVowelWord, "เดิน")
        XCTAssertEqual(manager.currentCard?.id, cardID)
        XCTAssertEqual(manager.attempt, initialAttempt + 1)

        practiceSharedVowel(.longClosed)
        XCTAssertEqual(currentVowelWord, "เดิน")
        XCTAssertEqual(manager.currentCard?.id, cardID)
        XCTAssertEqual(manager.attempt, initialAttempt + 2)
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
        manager.syncDeck()
        XCTAssertEqual(sharedFormWord(), "เดิน", "its long slot passes both the filter and the chapter")
    }

    func test_sharedForm_day5_shortOnly_isExcluded() {
        settings.bookProgress = .day5
        settings.longVowels = false
        manager.syncDeck()
        XCTAssertNil(sharedFormWord(), "its short slot is not taught; its long slot is filtered out")
    }

    func test_sharedForm_day5_shortOnlyWithNotTaught_presentsShortSlot() {
        settings.bookProgress = .day5
        settings.longVowels = false
        settings.showNotInBook = true
        manager.syncDeck()
        XCTAssertEqual(sharedFormWord(), "เงิน")
    }

    func test_sharedForm_day5_bothDurations_presentsLongSlot() {
        settings.bookProgress = .day5
        manager.syncDeck()
        XCTAssertEqual(sharedFormWord(), "เดิน")
    }

    /// Without a chapter, the duration filter alone picks the slot. Before,
    /// Long only dropped the card because only its short slot was checked.
    func test_sharedForm_off_followsDurationFilter() {
        XCTAssertEqual(sharedFormWord(), "เงิน", "both durations: the card's own (short) slot")
        settings.shortVowels = false
        manager.syncDeck()
        XCTAssertEqual(sharedFormWord(), "เดิน")
        settings.shortVowels = true
        settings.longVowels = false
        manager.syncDeck()
        XCTAssertEqual(sharedFormWord(), "เงิน")
    }

    /// The progress id and accepted durations never follow the presented slot.
    func test_sharedForm_presentedSlot_keepsIdAndAnswers() throws {
        let original = try vowelCard("เกิ-")
        settings.shortVowels = false
        manager.syncDeck()
        let item = try XCTUnwrap(manager.filteredCards.first { $0.id == original.id })
        XCTAssertEqual(item.fixedAnswerQuestions[.vowelDuration], ["Short", "Long"])
    }

    func test_sharedForm_ownSlotInScope_presentsOwnSlot() throws {
        settings.bookProgress = .day5
        settings.showNotInBook = true
        manager.syncDeck()
        let card = try deckVowelCard("เกิ-")
        XCTAssertEqual(card.shownDuration, card.duration)
    }
}

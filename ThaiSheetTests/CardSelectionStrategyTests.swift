//
//  CardSelectionStrategyTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

private final class InMemoryKeyValueStore: KeyValueStore {
    private var values: [String: Any] = [:]

    func set(_ value: Any?, forKey key: String) {
        values[key] = value
    }

    func set(_ value: Bool, forKey key: String) {
        values[key] = value
    }

    func object(forKey key: String) -> Any? {
        values[key]
    }

    func string(forKey key: String) -> String? {
        values[key] as? String
    }

    func data(forKey key: String) -> Data? {
        values[key] as? Data
    }

    func removeObject(forKey key: String) {
        values.removeValue(forKey: key)
    }

    @discardableResult
    func synchronize() -> Bool {
        true
    }
}

@MainActor
final class SequentialStrategyTests: XCTestCase {

    private var strategy: SequentialStrategy!
    private var learningModel: LearningModel!
    private var testStore: InMemoryKeyValueStore!
    private var testCards: [FlashcardItem]!

    override func setUp() {
        super.setUp()
        testStore = InMemoryKeyValueStore()
        strategy = SequentialStrategy()
        learningModel = LearningModel(store: testStore)

        let consonants = Consonant.loadAll()
        XCTAssertFalse(consonants.isEmpty, "Need bundle data for tests")
        testCards = consonants.prefix(5).map { FlashcardItem.consonant($0) }

        strategy.update(cards: testCards, learningModel: learningModel)
    }

    override func tearDown() {
        strategy = nil
        learningModel = nil
        testStore = nil
        testCards = nil
        super.tearDown()
    }

    // MARK: - currentCard

    func test_currentCard_initialState_returnsFirstCard() {
        XCTAssertEqual(strategy.currentCard?.id, testCards[0].id)
    }

    func test_currentCard_emptyCards_returnsNil() {
        strategy.update(cards: [], learningModel: learningModel)
        XCTAssertNil(strategy.currentCard)
    }

    // MARK: - nextCard

    func test_nextCard_advancesToSecondCard() {
        strategy.nextCard()
        XCTAssertEqual(strategy.currentCard?.id, testCards[1].id)
    }

    func test_nextCard_multipleCalls_advancesSequentially() {
        for i in 1..<testCards.count {
            strategy.nextCard()
            XCTAssertEqual(strategy.currentCard?.id, testCards[i].id,
                           "After \(i) next calls, expected card at index \(i)")
        }
    }

    func test_nextCard_wrapsAround() {
        // Advance past the last card
        for _ in 0..<testCards.count {
            strategy.nextCard()
        }
        // Should wrap back to first card
        XCTAssertEqual(strategy.currentCard?.id, testCards[0].id)
    }

    func test_nextCard_emptyCards_doesNotCrash() {
        strategy.update(cards: [], learningModel: learningModel)
        strategy.nextCard() // should not crash
        XCTAssertNil(strategy.currentCard)
    }

    // MARK: - previousCard

    func test_previousCard_fromFirst_wrapsToLast() {
        strategy.previousCard()
        XCTAssertEqual(strategy.currentCard?.id, testCards[testCards.count - 1].id)
    }

    func test_previousCard_fromSecond_goesToFirst() {
        strategy.nextCard() // go to index 1
        strategy.previousCard() // back to index 0
        XCTAssertEqual(strategy.currentCard?.id, testCards[0].id)
    }

    func test_previousCard_wrapsCorrectly() {
        // Go back from first
        strategy.previousCard()
        XCTAssertEqual(strategy.currentCard?.id, testCards.last?.id)

        // Go back one more
        strategy.previousCard()
        XCTAssertEqual(strategy.currentCard?.id, testCards[testCards.count - 2].id)
    }

    func test_previousCard_emptyCards_doesNotCrash() {
        strategy.update(cards: [], learningModel: learningModel)
        strategy.previousCard() // should not crash
        XCTAssertNil(strategy.currentCard)
    }

    // MARK: - reset

    func test_reset_goesToIndex0() {
        strategy.nextCard()
        strategy.nextCard()
        strategy.nextCard()
        XCTAssertEqual(strategy.currentCard?.id, testCards[3].id)

        strategy.reset()
        XCTAssertEqual(strategy.currentCard?.id, testCards[0].id)
    }

    // MARK: - jumpTo(index:)

    func test_jumpTo_validIndex_goesToThatIndex() {
        strategy.jumpTo(index: 3)
        XCTAssertEqual(strategy.currentCard?.id, testCards[3].id)
    }

    func test_jumpTo_firstIndex_goesToFirst() {
        strategy.nextCard()
        strategy.nextCard()
        strategy.jumpTo(index: 0)
        XCTAssertEqual(strategy.currentCard?.id, testCards[0].id)
    }

    func test_jumpTo_lastIndex_goesToLast() {
        strategy.jumpTo(index: testCards.count - 1)
        XCTAssertEqual(strategy.currentCard?.id, testCards.last?.id)
    }

    func test_jumpTo_negativeIndex_clampsToZero() {
        strategy.jumpTo(index: -5)
        XCTAssertEqual(strategy.currentCard?.id, testCards[0].id)
    }

    func test_jumpTo_indexBeyondCount_clampsToLast() {
        strategy.jumpTo(index: 100)
        XCTAssertEqual(strategy.currentCard?.id, testCards.last?.id)
    }

    func test_jumpTo_emptyCards_doesNotCrash() {
        strategy.update(cards: [], learningModel: learningModel)
        strategy.jumpTo(index: 5) // should not crash
        XCTAssertNil(strategy.currentCard)
    }

    // MARK: - indexOf

    func test_indexOf_existingCard_returnsCorrectIndex() {
        for (i, card) in testCards.enumerated() {
            XCTAssertEqual(strategy.indexOf(cardId: card.id), i)
        }
    }

    func test_indexOf_nonexistentCard_returnsNil() {
        XCTAssertNil(strategy.indexOf(cardId: "nonexistent-card"))
    }

    // MARK: - update

    func test_update_withNewCards_keepsIndexValid() {
        strategy.jumpTo(index: 4) // Go to last card in 5-card list
        // Update with fewer cards
        let fewerCards = Array(testCards.prefix(2))
        strategy.update(cards: fewerCards, learningModel: learningModel)
        // Index should be reset to 0 since 4 >= 2
        XCTAssertEqual(strategy.currentCard?.id, fewerCards[0].id)
    }

    func test_update_withSameOrMoreCards_keepsCurrentIndex() {
        strategy.jumpTo(index: 2)
        // Update with the same cards
        strategy.update(cards: testCards, learningModel: learningModel)
        XCTAssertEqual(strategy.currentCard?.id, testCards[2].id)
    }
}

@MainActor
final class WanikaniStrategyTests: XCTestCase {

    private var strategy: WanikaniStrategy!
    private var learningModel: LearningModel!
    private var testStore: InMemoryKeyValueStore!
    private var testCards: [FlashcardItem]!

    override func setUp() {
        super.setUp()
        testStore = InMemoryKeyValueStore()
        strategy = WanikaniStrategy()
        learningModel = LearningModel(store: testStore)

        let consonants = Consonant.loadAll()
        XCTAssertFalse(consonants.isEmpty, "Need bundle data for tests")
        testCards = consonants.prefix(10).map { FlashcardItem.consonant($0) }

        strategy.update(cards: testCards, learningModel: learningModel)
    }

    override func tearDown() {
        strategy = nil
        learningModel = nil
        testStore = nil
        testCards = nil
        super.tearDown()
    }

    // MARK: - currentCard after update

    func test_currentCard_afterUpdate_isNotNil() {
        // update() should trigger initial card selection
        XCTAssertNotNil(strategy.currentCard)
    }

    func test_currentCard_afterUpdate_isFromCardList() {
        let currentId = strategy.currentCard?.id
        XCTAssertNotNil(currentId)
        XCTAssertTrue(testCards.contains(where: { $0.id == currentId }))
    }

    // MARK: - nextCard

    func test_nextCard_selectsFromDueCardsPreferentially() {
        // All cards start as "new" which is due, so nextCard should select one
        strategy.nextCard()
        XCTAssertNotNil(strategy.currentCard)
        XCTAssertTrue(testCards.contains(where: { $0.id == strategy.currentCard?.id }))
    }

    func test_nextCard_neverReturnsSameCardTwiceInRow_whenAlternativesExist() {
        // With 10 cards, there should always be alternatives
        var lastId = strategy.currentCard?.id
        var sawDifferentCard = false

        // Try 20 times to see a different card
        for _ in 0..<20 {
            strategy.nextCard()
            if strategy.currentCard?.id != lastId {
                sawDifferentCard = true
                break
            }
            lastId = strategy.currentCard?.id
        }

        XCTAssertTrue(sawDifferentCard,
                       "Should have seen a different card in 20 attempts with 10 available cards")
    }

    func test_nextCard_returnsCardFromList() {
        for _ in 0..<10 {
            strategy.nextCard()
            let currentId = strategy.currentCard?.id
            XCTAssertNotNil(currentId)
            XCTAssertTrue(testCards.contains(where: { $0.id == currentId }),
                          "Card \(currentId ?? "nil") should be in the test cards list")
        }
    }

    // MARK: - previousCard

    func test_previousCard_navigatesHistory() {
        // Record current card
        let firstCard = strategy.currentCard
        XCTAssertNotNil(firstCard)

        // Go forward
        strategy.nextCard()
        let secondCard = strategy.currentCard
        XCTAssertNotNil(secondCard)

        // Go back
        strategy.previousCard()
        XCTAssertEqual(strategy.currentCard?.id, firstCard?.id,
                       "previousCard should go back to the first card in history")
    }

    func test_previousCard_atStartOfHistory_staysPut() {
        let initialCard = strategy.currentCard

        // Try to go back before history exists
        strategy.previousCard()
        XCTAssertEqual(strategy.currentCard?.id, initialCard?.id,
                       "previousCard at start of history should not change current card")
    }

    func test_previousCard_multipleSteps_navigatesFullHistory() {
        var historyIds: [String] = []
        if let firstId = strategy.currentCard?.id {
            historyIds.append(firstId)
        }

        // Build up history
        for _ in 0..<4 {
            strategy.nextCard()
            if let id = strategy.currentCard?.id {
                historyIds.append(id)
            }
        }

        // Navigate back through history
        for i in stride(from: historyIds.count - 2, through: 0, by: -1) {
            strategy.previousCard()
            XCTAssertEqual(strategy.currentCard?.id, historyIds[i],
                           "Going back should match history at index \(i)")
        }
    }

    func test_previousCard_thenNextCard_navigatesForwardInHistory() {
        let firstCard = strategy.currentCard

        strategy.nextCard()
        let secondCard = strategy.currentCard

        strategy.nextCard()
        // Now at third card

        // Go back to second
        strategy.previousCard()
        XCTAssertEqual(strategy.currentCard?.id, secondCard?.id)

        // Go back to first
        strategy.previousCard()
        XCTAssertEqual(strategy.currentCard?.id, firstCard?.id)

        // Go forward should return to second (existing history)
        strategy.nextCard()
        XCTAssertEqual(strategy.currentCard?.id, secondCard?.id)
    }

    // MARK: - reset

    func test_reset_clearsHistoryAndPicksNewCard() {
        // Navigate forward a few times
        strategy.nextCard()
        strategy.nextCard()
        strategy.nextCard()

        strategy.reset()

        // Should have a card (picks new one)
        XCTAssertNotNil(strategy.currentCard)

        // previousCard should not work since history was cleared
        let afterReset = strategy.currentCard
        strategy.previousCard()
        XCTAssertEqual(strategy.currentCard?.id, afterReset?.id,
                       "After reset, there should be no history to go back to")
    }

    func test_reset_withEmptyCards_currentCardIsNil() {
        strategy.update(cards: [], learningModel: learningModel)
        strategy.reset()
        XCTAssertNil(strategy.currentCard)
    }

    // MARK: - jumpTo(card:)

    func test_jumpTo_setsCurrentCard() {
        let targetCard = testCards[5]
        strategy.jumpTo(card: targetCard)
        XCTAssertEqual(strategy.currentCard?.id, targetCard.id)
    }

    func test_jumpTo_addsToHistory() {
        let firstCard = strategy.currentCard

        let targetCard = testCards[5]
        strategy.jumpTo(card: targetCard)
        XCTAssertEqual(strategy.currentCard?.id, targetCard.id)

        // Should be able to go back to previous card
        strategy.previousCard()
        XCTAssertEqual(strategy.currentCard?.id, firstCard?.id)
    }

    func test_jumpTo_multipleJumps_buildsHistory() {
        let card3 = testCards[3]
        let card7 = testCards[7]

        strategy.jumpTo(card: card3)
        strategy.jumpTo(card: card7)

        XCTAssertEqual(strategy.currentCard?.id, card7.id)

        strategy.previousCard()
        XCTAssertEqual(strategy.currentCard?.id, card3.id)
    }

    // MARK: - SRS Card Selection Priority

    func test_nextCard_prefersNewCards_overMasteredCards() {
        // Master all but one card
        for i in 0..<testCards.count - 1 {
            for _ in 0..<8 {
                learningModel.recordResult(for: testCards[i], correct: true, fullTesting: true)
            }
        }
        // The last card is still "new"
        let newCard = testCards.last!

        // Update strategy with the new state
        strategy.update(cards: testCards, learningModel: learningModel)

        // Navigate several times - should keep getting the unmastered card
        var sawNewCard = false
        for _ in 0..<20 {
            strategy.nextCard()
            if strategy.currentCard?.id == newCard.id {
                sawNewCard = true
                break
            }
        }
        XCTAssertTrue(sawNewCard, "Should eventually select the only non-mastered card")
    }

    // MARK: - Empty cards

    func test_emptyCards_currentCardIsNil() {
        // Use the existing strategy but update with empty cards
        strategy.update(cards: [], learningModel: learningModel)
        XCTAssertNil(strategy.currentCard)
    }

    func test_emptyCards_nextCard_doesNotCrash() {
        strategy.update(cards: [], learningModel: learningModel)
        strategy.nextCard()
        XCTAssertNil(strategy.currentCard)
    }

    func test_emptyCards_previousCard_doesNotCrash() {
        strategy.update(cards: [], learningModel: learningModel)
        strategy.previousCard()
        XCTAssertNil(strategy.currentCard)
    }

    // MARK: - Single card

    func test_singleCard_nextCard_returnsSameCard() {
        let singleCardList = [testCards[0]]
        strategy.update(cards: singleCardList, learningModel: learningModel)

        let firstCard = strategy.currentCard
        XCTAssertNotNil(firstCard)

        strategy.nextCard()
        // With only 1 card, it must return that card (fallback to current)
        XCTAssertNotNil(strategy.currentCard)
        XCTAssertEqual(strategy.currentCard?.id, firstCard?.id)
    }

    // MARK: - Mastered cards never resurface while learning remains (#26)

    /// Advance a card all the way to `.mastered` (stage 8 = 8 correct answers).
    private func master(_ card: FlashcardItem) {
        for _ in 0..<8 {
            learningModel.recordResult(for: card, correct: true, fullTesting: true)
        }
        XCTAssertEqual(learningModel.getProgress(for: card).srsStage, .mastered,
                       "Card should be mastered after 8 correct full-testing answers")
    }

    func test_nextCard_neverReturnsMasteredCard_whenCurrentIsOnlyUnmastered() {
        // Master every card except the first.
        for i in 1..<testCards.count {
            master(testCards[i])
        }
        let onlyUnmastered = testCards[0]
        strategy.update(cards: testCards, learningModel: learningModel)

        // Force the current card to be the sole unmastered card, reproducing the
        // fallback path where every non-current card is mastered.
        strategy.jumpTo(card: onlyUnmastered)
        XCTAssertEqual(strategy.currentCard?.id, onlyUnmastered.id)

        // Repeated navigation must never surface a mastered card; it should stay
        // on the only card still being learned.
        for _ in 0..<30 {
            strategy.nextCard()
            let currentId = strategy.currentCard?.id
            XCTAssertEqual(currentId, onlyUnmastered.id,
                           "Smart selection must stay on the only unmastered card, not resurface a mastered one")
            XCTAssertNotEqual(learningModel.getProgress(for: strategy.currentCard!).srsStage, .mastered)
        }
    }

    func test_nextCard_allMastered_showsACardAndDoesNotCycle() {
        // Master the entire deck.
        for card in testCards {
            master(card)
        }
        strategy.update(cards: testCards, learningModel: learningModel)

        // Documented all-mastered behavior: the UI still has a card to show.
        XCTAssertNotNil(strategy.currentCard,
                        "With an all-mastered deck, a card is still surfaced so the UI is not empty")

        // Once a card is current, navigation stays put rather than randomly
        // cycling through mastered content.
        strategy.jumpTo(card: testCards[3])
        strategy.nextCard()
        XCTAssertEqual(strategy.currentCard?.id, testCards[3].id,
                       "All-mastered navigation should stay on the current card")
    }

    func test_singleUnmasteredCard_nextCard_staysOnIt() {
        let onlyCard = testCards[0]
        strategy.update(cards: [onlyCard], learningModel: learningModel)

        strategy.nextCard()
        XCTAssertEqual(strategy.currentCard?.id, onlyCard.id,
                       "A one-card deck has nowhere else to go")
    }

    func test_singleMasteredCard_isStillSurfaced() {
        let onlyCard = testCards[0]
        master(onlyCard)

        // reset() re-selects with no current card — the one path that is allowed
        // to return mastered content. (The shared strategy is reused rather than
        // constructing one here: a short-lived @Observable instance trips the
        // toolchain invalid-free described under Testing Gotchas in CLAUDE.md.)
        strategy.update(cards: [onlyCard], learningModel: learningModel)
        strategy.reset()

        XCTAssertEqual(strategy.currentCard?.id, onlyCard.id,
                       "A fully mastered deck still shows a card rather than an empty screen")
    }

    // MARK: - Selection priority: due > new > future (#26)

    /// Builds a model whose stored progress is seeded directly, so a card can be
    /// genuinely overdue without waiting out an SRS interval. The shared
    /// `strategy` is then pointed at it — LearningModel carries the empty
    /// `nonisolated deinit` guard, so a short-lived one is safe; a short-lived
    /// strategy is not.
    private func makeSeededModel(_ progress: [String: CardProgress]) throws -> LearningModel {
        let seededStore = InMemoryKeyValueStore()
        seededStore.set(try JSONEncoder().encode(progress), forKey: LearningModel.storageKey)
        return LearningModel(store: seededStore)
    }

    private func reviewedProgress(
        for card: FlashcardItem,
        stage: SRSStage,
        nextReviewIn interval: TimeInterval
    ) -> CardProgress {
        CardProgress(
            cardId: card.id,
            correctCount: stage.rawValue,
            incorrectCount: 0,
            lastReviewed: Date().addingTimeInterval(-interval - 60),
            srsStage: stage,
            nextReviewDate: Date().addingTimeInterval(interval)
        )
    }

    func test_nextCard_prefersDueCard_overNewAndFuture() throws {
        let anchor = testCards[0]
        let dueCard = testCards[1]
        let newCard = testCards[2]
        let futureCard = testCards[3]

        let model = try makeSeededModel([
            dueCard.id: reviewedProgress(for: dueCard, stage: .apprentice1, nextReviewIn: -3600),
            futureCard.id: reviewedProgress(for: futureCard, stage: .apprentice1, nextReviewIn: 3600),
        ])
        XCTAssertTrue(model.getProgress(for: dueCard).isDue)
        XCTAssertFalse(model.getProgress(for: futureCard).isDue)
        XCTAssertEqual(model.getProgress(for: newCard).srsStage, .new)

        let deck = [anchor, dueCard, newCard, futureCard]
        strategy.update(cards: deck, learningModel: model)
        strategy.jumpTo(card: anchor)

        strategy.nextCard()
        XCTAssertEqual(strategy.currentCard?.id, dueCard.id,
                       "Priority 1 is the due card, ahead of both new and future cards")
    }

    func test_nextCard_prefersNewCard_overFuture_whenNothingIsDue() throws {
        let anchor = testCards[0]
        let newCard = testCards[1]
        let futureCard = testCards[2]

        let model = try makeSeededModel([
            futureCard.id: reviewedProgress(for: futureCard, stage: .apprentice1, nextReviewIn: 3600),
        ])

        let deck = [anchor, newCard, futureCard]
        strategy.update(cards: deck, learningModel: model)
        strategy.jumpTo(card: anchor)

        strategy.nextCard()
        XCTAssertEqual(strategy.currentCard?.id, newCard.id,
                       "Priority 2 is the new card; future cards come last")
    }

    func test_nextCard_fallsBackToFutureCard_whenNothingIsDueOrNew() throws {
        let anchor = testCards[0]
        let soonCard = testCards[1]
        let laterCard = testCards[2]

        let model = try makeSeededModel([
            soonCard.id: reviewedProgress(for: soonCard, stage: .apprentice1, nextReviewIn: 3600),
            laterCard.id: reviewedProgress(for: laterCard, stage: .apprentice1, nextReviewIn: 7200),
            anchor.id: reviewedProgress(for: anchor, stage: .apprentice1, nextReviewIn: 1800),
        ])

        let deck = [anchor, soonCard, laterCard]
        strategy.update(cards: deck, learningModel: model)
        strategy.jumpTo(card: anchor)

        strategy.nextCard()
        XCTAssertEqual(strategy.currentCard?.id, soonCard.id,
                       "Priority 3 shows the soonest upcoming card")
    }

    // MARK: - History is a record of what was shown (#26)

    func test_previousCard_returnsEarlierCard_evenAfterItBecameMastered() {
        let first = testCards[0]
        let second = testCards[1]
        strategy.jumpTo(card: first)
        strategy.jumpTo(card: second)

        master(first)

        strategy.previousCard()
        XCTAssertEqual(strategy.currentCard?.id, first.id,
                       "Back navigation replays what was actually shown; mastering a card does not rewrite history")
    }

    func test_nextCard_forwardThroughHistory_returnsLaterCard_evenAfterItBecameMastered() {
        let first = testCards[0]
        let second = testCards[1]
        strategy.jumpTo(card: first)
        strategy.jumpTo(card: second)
        strategy.previousCard()
        XCTAssertEqual(strategy.currentCard?.id, first.id)

        master(second)

        strategy.nextCard()
        XCTAssertEqual(strategy.currentCard?.id, second.id,
                       "Forward navigation replays the recorded entry rather than re-selecting")
    }

    func test_previousCard_afterStayingOnLastUnmasteredCard_returnsToEarlierCard() {
        let earlier = testCards[0]
        let onlyUnmastered = testCards[1]
        for card in testCards where card.id != onlyUnmastered.id {
            master(card)
        }
        strategy.update(cards: testCards, learningModel: learningModel)

        strategy.jumpTo(card: earlier)
        strategy.jumpTo(card: onlyUnmastered)

        // Several "next" presses that all stay on the last unmastered card.
        for _ in 0..<5 {
            strategy.nextCard()
            XCTAssertEqual(strategy.currentCard?.id, onlyUnmastered.id)
        }

        // Those repeats are coalesced into the single entry already there, so
        // one step back reaches real earlier content instead of looking
        // unresponsive five times over.
        strategy.previousCard()
        XCTAssertEqual(strategy.currentCard?.id, earlier.id,
                       "Repeated stay-put steps must not each become their own history entry")
    }

    func test_nextCard_afterStayingPut_stillMovesForwardThroughHistory() {
        let earlier = testCards[0]
        let onlyUnmastered = testCards[1]
        for card in testCards where card.id != onlyUnmastered.id {
            master(card)
        }
        strategy.update(cards: testCards, learningModel: learningModel)

        strategy.jumpTo(card: earlier)
        strategy.jumpTo(card: onlyUnmastered)
        strategy.nextCard()
        strategy.previousCard()
        XCTAssertEqual(strategy.currentCard?.id, earlier.id)

        // Forward again returns to the coalesced entry, not to a duplicate.
        strategy.nextCard()
        XCTAssertEqual(strategy.currentCard?.id, onlyUnmastered.id)
        strategy.nextCard()
        XCTAssertEqual(strategy.currentCard?.id, onlyUnmastered.id,
                       "Past the end of history, selection stays on the only unmastered card")
    }
}

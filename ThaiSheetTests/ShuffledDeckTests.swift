//
//  ShuffledDeckTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

/// Keeps short-lived models alive for the whole run (see the Swift 6.2
/// deinit note in CLAUDE.md "Testing Gotchas").
private enum Retained {
    nonisolated(unsafe) static var objects: [AnyObject] = []
}

/// Shuffled mode through `FlashcardManager`: what is recorded to SRS, cards
/// opened from Reference, and mode changes.
@MainActor
final class ShuffledDeckTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settings: FlashcardSettings!
    private var manager: FlashcardManager!

    override func setUp() {
        super.setUp()
        suiteName = "ShuffledDeckTests_\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settings = FlashcardSettings(defaults: defaults)
        // A small deck: the low-class consonants only
        settings.deselectAll()
        settings.consonantsEnabled = true
        settings.lowConsonants = true
        settings.selectionMode = .shuffled

        let data = ThaiDataStore()
        manager = FlashcardManager(
            settings: settings,
            learningModel: LearningModel(store: defaults),
            data: data,
            shuffledStrategy: ShuffledStrategy(generator: SeededRandomNumberGenerator(seed: 7))
        )
        manager.learningModel.advanceClockOnEachReview()
        Retained.objects.append(contentsOf: [data, manager] as [AnyObject])
        XCTAssertGreaterThan(manager.filteredCards.count, 3, "Need a few cards for these tests")
    }

    override func tearDown() {
        manager = nil
        settings = nil
        defaults = nil
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private var current: FlashcardItem {
        get throws { try XCTUnwrap(manager.currentCard) }
    }

    private func progress(_ card: FlashcardItem) -> CardProgress {
        manager.learningModel.getProgress(for: card)
    }

    /// Moves past every remaining card of the pass or retry round.
    private func finishRound() {
        while manager.currentCard != nil {
            manager.nextCard()
        }
    }

    /// A consonant in the deck that is not the card showing, as Reference opens it.
    private func otherConsonant() throws -> ReferenceItem {
        let showing = try current.id
        let card = try XCTUnwrap(manager.filteredCards.first { $0.id != showing })
        guard case .consonant(let consonant, _) = card else { throw XCTSkip("not a consonant") }
        return .consonant(consonant.character)
    }

    // MARK: - Grading

    func test_firstPassMiss_isRecordedAndDemotes() throws {
        let card = try current
        XCTAssertEqual(manager.recordAnswer(for: card, correct: false), .counted)
        XCTAssertEqual(progress(card).srsStage, .learning1)
        XCTAssertEqual(progress(card).incorrectCount, 1)
    }

    func test_repeatAnswerInPass_isPracticeOnly() throws {
        let card = try current
        manager.recordAnswer(for: card, correct: false)
        let recorded = progress(card)

        manager.nextCard()
        manager.previousCard()
        XCTAssertEqual(try current.id, card.id)
        XCTAssertNil(manager.recordAnswer(for: try current, correct: false))
        XCTAssertEqual(progress(card), recorded)
    }

    func test_retryAnswers_doNotChangeProgress() throws {
        let missed = try current
        manager.recordAnswer(for: missed, correct: false)
        finishRound()
        manager.startRetry()

        XCTAssertEqual(try current.id, missed.id)
        let recorded = progress(missed)
        XCTAssertNil(manager.recordAnswer(for: try current, correct: true))
        XCTAssertNil(manager.recordAnswer(for: try current, correct: false))
        XCTAssertEqual(progress(missed), recorded)
    }

    func test_otherModes_alwaysRecord() throws {
        for mode in [SelectionMode.smart, .sequential] {
            settings.selectionMode = mode
            manager.applySelectionModeChange()
            let card = try current
            XCTAssertNotNil(manager.recordAnswer(for: card, correct: false), "mode: \(mode)")
            XCTAssertNotNil(manager.recordAnswer(for: card, correct: false), "mode: \(mode)")
        }
    }

    func test_answeringASkippedCard_isRecorded() throws {
        finishRound()
        XCTAssertEqual(manager.roundSummary?.skipped, manager.filteredCards.count)
        manager.startSkipped()
        XCTAssertEqual(manager.roundPosition?.phase, .skipped)
        let skippedCard = try current
        XCTAssertEqual(manager.recordAnswer(for: skippedCard, correct: true), .counted)
        XCTAssertEqual(progress(skippedCard).srsStage, .learning1)
    }

    func test_practiceMissedAgain_doesNotChangeProgress() throws {
        let missed = try current
        manager.recordAnswer(for: missed, correct: false)
        finishRound()
        manager.startRetry()
        manager.recordAnswer(for: try current, correct: true)
        finishRound()
        let recorded = progress(missed)

        let attempt = manager.attempt
        manager.startPracticeMissed()
        XCTAssertEqual(manager.attempt, attempt + 1)
        XCTAssertEqual(manager.roundPosition?.phase, .practice)
        XCTAssertNil(manager.recordAnswer(for: try current, correct: false))
        XCTAssertEqual(progress(missed), recorded)
    }

    // MARK: - Practice from Reference

    func test_referencePractice_duringPass_returnsToSameCardAndPosition() throws {
        manager.nextCard()
        let roundCard = try current.id
        let position = try XCTUnwrap(manager.roundPosition)

        for swipe in [manager.nextCard, manager.previousCard] {
            manager.practice(try otherConsonant())
            XCTAssertNotEqual(try current.id, roundCard)
            XCTAssertNil(manager.roundPosition)

            swipe()
            XCTAssertEqual(try current.id, roundCard)
            XCTAssertEqual(manager.roundPosition, position)
        }
    }

    func test_referencePractice_isRecorded_andLeavesRoundGradingAlone() throws {
        let roundCard = try current
        manager.practice(try otherConsonant())
        let opened = try current
        XCTAssertEqual(manager.recordAnswer(for: opened, correct: false), .counted)
        XCTAssertEqual(progress(opened).incorrectCount, 1)

        manager.nextCard()
        XCTAssertEqual(try current.id, roundCard.id)
        XCTAssertEqual(manager.recordAnswer(for: roundCard, correct: false), .counted,
                       "The round card's first answer is still graded")
    }

    func test_referencePractice_fromSummary_replacesAndRestoresIt() throws {
        manager.recordAnswer(for: try current, correct: false)
        finishRound()
        let summary = try XCTUnwrap(manager.roundSummary)

        let deckCard = try XCTUnwrap(manager.filteredCards.first)
        guard case .consonant(let consonant, _) = deckCard else { throw XCTSkip("not a consonant") }
        manager.practice(.consonant(consonant.character))
        XCTAssertEqual(try current.id, deckCard.id)
        XCTAssertNil(manager.roundSummary)

        manager.nextCard()
        XCTAssertNil(manager.currentCard)
        XCTAssertEqual(manager.roundSummary, summary)
    }

    // MARK: - Mode and deck changes

    func test_modeChange_isNewAttempt_andShuffledStartsFresh() throws {
        manager.recordAnswer(for: try current, correct: false)
        manager.nextCard()
        manager.nextCard()

        let attempt = manager.attempt
        settings.selectionMode = .sequential
        manager.applySelectionModeChange()
        XCTAssertEqual(manager.attempt, attempt + 1)
        XCTAssertNil(manager.roundPosition)

        settings.selectionMode = .shuffled
        manager.applySelectionModeChange()
        XCTAssertEqual(manager.attempt, attempt + 2)
        XCTAssertEqual(manager.roundPosition?.number, 1)
        XCTAssertEqual(manager.roundPosition?.phase, .pass)
        XCTAssertEqual(manager.recordAnswer(for: try current, correct: true), .counted,
                       "A fresh pass grades first answers again")
    }

    func test_deckChange_startsFreshPass() throws {
        manager.nextCard()
        manager.nextCard()
        settings.midConsonants = true
        manager.syncDeck()
        XCTAssertEqual(manager.roundPosition?.number, 1)
        XCTAssertEqual(manager.roundPosition?.count, manager.filteredCards.count)
    }

    func test_retryAndNewRound_areNewAttempts() throws {
        manager.recordAnswer(for: try current, correct: false)
        finishRound()
        var attempt = manager.attempt
        manager.startRetry()
        XCTAssertEqual(manager.attempt, attempt + 1)
        XCTAssertEqual(manager.roundPosition?.phase, .retry)

        attempt = manager.attempt
        manager.startNewRound()
        XCTAssertEqual(manager.attempt, attempt + 1)
        XCTAssertEqual(manager.roundPosition?.phase, .pass)
    }
}

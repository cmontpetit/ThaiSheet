//
//  LearningModelTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

@MainActor
final class LearningModelTests: XCTestCase {

    private var model: LearningModel!
    private var testCards: [FlashcardItem]!

    override func setUp() {
        super.setUp()
        // Clear any persisted progress from previous test runs
        UserDefaults.standard.removeObject(forKey: "learningProgress")
        model = LearningModel()

        // Load real data from bundle for FlashcardItem instances
        let consonants = Consonant.loadAll()
        XCTAssertFalse(consonants.isEmpty, "Need bundle data for tests")
        testCards = consonants.prefix(5).map { FlashcardItem.consonant($0) }
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "learningProgress")
        model = nil
        testCards = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private var card1: FlashcardItem { testCards[0] }
    private var card2: FlashcardItem { testCards[1] }
    private var card3: FlashcardItem { testCards[2] }

    // MARK: - recordResult correct with full testing

    func test_recordResult_correctFullTesting_advancesStage() {
        model.recordResult(for: card1, correct: true, fullTesting: true)
        XCTAssertEqual(model.srsStage(for: card1), .learning1)
    }

    func test_recordResult_twoCorrectFullTesting_advancesToLearning2() {
        model.recordResult(for: card1, correct: true, fullTesting: true)
        model.recordResult(for: card1, correct: true, fullTesting: true)
        XCTAssertEqual(model.srsStage(for: card1), .learning2)
    }

    func test_recordResult_multipleCorrect_advancesThroughStages() {
        // Advance through all stages: new -> learning1 -> learning2 -> apprentice1 ...
        let expectedStages: [SRSStage] = [
            .learning1, .learning2, .apprentice1, .apprentice2,
            .familiar1, .familiar2, .confident, .mastered
        ]
        for (i, expected) in expectedStages.enumerated() {
            model.recordResult(for: card1, correct: true, fullTesting: true)
            XCTAssertEqual(model.srsStage(for: card1), expected,
                           "After \(i + 1) correct answers, expected \(expected)")
        }
    }

    func test_recordResult_correctFullTesting_atMastered_staysMastered() {
        // Advance to mastered
        for _ in 0..<8 {
            model.recordResult(for: card1, correct: true, fullTesting: true)
        }
        XCTAssertEqual(model.srsStage(for: card1), .mastered)

        // Another correct answer keeps it mastered
        model.recordResult(for: card1, correct: true, fullTesting: true)
        XCTAssertEqual(model.srsStage(for: card1), .mastered)
    }

    // MARK: - recordResult incorrect

    func test_recordResult_incorrect_demotesStage() {
        // Advance to apprentice1 (3 correct)
        model.recordResult(for: card1, correct: true, fullTesting: true)
        model.recordResult(for: card1, correct: true, fullTesting: true)
        model.recordResult(for: card1, correct: true, fullTesting: true)
        XCTAssertEqual(model.srsStage(for: card1), .apprentice1)

        // Incorrect drops by 2 -> learning1
        model.recordResult(for: card1, correct: false)
        XCTAssertEqual(model.srsStage(for: card1), .learning1)
    }

    func test_recordResult_incorrect_incrementsIncorrectCount() {
        model.recordResult(for: card1, correct: false)
        let progress = model.getProgress(for: card1)
        XCTAssertEqual(progress.incorrectCount, 1)
        XCTAssertEqual(progress.correctCount, 0)
    }

    func test_recordResult_incorrect_fromNew_goesToLearning1() {
        model.recordResult(for: card1, correct: false)
        XCTAssertEqual(model.srsStage(for: card1), .learning1)
    }

    func test_recordResult_incorrect_fromLearning1_staysAtLearning1() {
        model.recordResult(for: card1, correct: true, fullTesting: true) // -> learning1
        model.recordResult(for: card1, correct: false) // learning1 demote -> learning1
        XCTAssertEqual(model.srsStage(for: card1), .learning1)
    }

    // MARK: - recordResult with partial testing (fullTesting: false)

    func test_recordResult_correctPartialTesting_capsAtFamiliar2() {
        // Advance to familiar2 with partial testing
        for _ in 0..<6 {
            model.recordResult(for: card1, correct: true, fullTesting: false)
        }
        XCTAssertEqual(model.srsStage(for: card1), .familiar2)

        // Another correct should NOT advance beyond familiar2
        model.recordResult(for: card1, correct: true, fullTesting: false)
        XCTAssertEqual(model.srsStage(for: card1), .familiar2,
                       "Partial testing should cap at familiar2")
    }

    func test_recordResult_partialTesting_doesNotReachConfident() {
        // Try 20 correct answers with partial testing
        for _ in 0..<20 {
            model.recordResult(for: card1, correct: true, fullTesting: false)
        }
        XCTAssertEqual(model.srsStage(for: card1), .familiar2)
        XCTAssertTrue(model.srsStage(for: card1) < .confident)
    }

    func test_recordResult_partialTesting_thenFullTesting_canAdvancePastCap() {
        // First get to familiar2 with partial testing
        for _ in 0..<10 {
            model.recordResult(for: card1, correct: true, fullTesting: false)
        }
        XCTAssertEqual(model.srsStage(for: card1), .familiar2)

        // Then full testing should allow advancement to confident
        model.recordResult(for: card1, correct: true, fullTesting: true)
        XCTAssertEqual(model.srsStage(for: card1), .confident)
    }

    // MARK: - getProgress

    func test_getProgress_unknownCard_returnsDefaultProgress() {
        let progress = model.getProgress(for: card1)
        XCTAssertEqual(progress.cardId, card1.id)
        XCTAssertEqual(progress.srsStage, .new)
        XCTAssertEqual(progress.correctCount, 0)
        XCTAssertEqual(progress.incorrectCount, 0)
        XCTAssertNil(progress.lastReviewed)
    }

    func test_getProgress_afterReview_returnsUpdatedProgress() {
        model.recordResult(for: card1, correct: true, fullTesting: true)
        let progress = model.getProgress(for: card1)
        XCTAssertEqual(progress.correctCount, 1)
        XCTAssertEqual(progress.srsStage, .learning1)
        XCTAssertNotNil(progress.lastReviewed)
    }

    func test_getProgressById_returnsDefaultForUnknownId() {
        let progress = model.getProgress(forId: "nonexistent-card")
        XCTAssertEqual(progress.cardId, "nonexistent-card")
        XCTAssertEqual(progress.srsStage, .new)
    }

    // MARK: - hasBeenReviewed

    func test_hasBeenReviewed_newCard_returnsFalse() {
        XCTAssertFalse(model.hasBeenReviewed(card1))
    }

    func test_hasBeenReviewed_afterCorrectReview_returnsTrue() {
        model.recordResult(for: card1, correct: true, fullTesting: true)
        XCTAssertTrue(model.hasBeenReviewed(card1))
    }

    func test_hasBeenReviewed_afterIncorrectReview_returnsTrue() {
        model.recordResult(for: card1, correct: false)
        XCTAssertTrue(model.hasBeenReviewed(card1))
    }

    // MARK: - isDue

    func test_isDue_newCard_returnsTrue() {
        XCTAssertTrue(model.isDue(card1))
    }

    func test_isDue_justReviewed_returnsFalse() {
        model.recordResult(for: card1, correct: true, fullTesting: true)
        // Just reviewed, next review is in 4 hours
        XCTAssertFalse(model.isDue(card1))
    }

    func test_isDue_masteredCard_returnsFalse() {
        for _ in 0..<8 {
            model.recordResult(for: card1, correct: true, fullTesting: true)
        }
        XCTAssertEqual(model.srsStage(for: card1), .mastered)
        XCTAssertFalse(model.isDue(card1))
    }

    // MARK: - srsStage

    func test_srsStage_unreviewed_returnsNew() {
        XCTAssertEqual(model.srsStage(for: card1), .new)
    }

    func test_srsStage_afterReview_returnsCorrectStage() {
        model.recordResult(for: card1, correct: true, fullTesting: true)
        XCTAssertEqual(model.srsStage(for: card1), .learning1)
    }

    // MARK: - Statistics: reviewedCardCount

    func test_reviewedCardCount_noReviews_returnsZero() {
        XCTAssertEqual(model.reviewedCardCount, 0)
    }

    func test_reviewedCardCount_afterReviewingMultipleCards_returnsCorrectCount() {
        model.recordResult(for: card1, correct: true, fullTesting: true)
        model.recordResult(for: card2, correct: false)
        XCTAssertEqual(model.reviewedCardCount, 2)
    }

    func test_reviewedCardCount_reviewingSameCardMultipleTimes_countsOnce() {
        model.recordResult(for: card1, correct: true, fullTesting: true)
        model.recordResult(for: card1, correct: true, fullTesting: true)
        model.recordResult(for: card1, correct: false)
        XCTAssertEqual(model.reviewedCardCount, 1)
    }

    // MARK: - Statistics: totalReviews

    func test_totalReviews_noReviews_returnsZero() {
        XCTAssertEqual(model.totalReviews, 0)
    }

    func test_totalReviews_multipleReviews_returnsTotalCount() {
        model.recordResult(for: card1, correct: true, fullTesting: true)
        model.recordResult(for: card1, correct: false)
        model.recordResult(for: card2, correct: true, fullTesting: true)
        XCTAssertEqual(model.totalReviews, 3)
    }

    // MARK: - Statistics: overallSuccessRate

    func test_overallSuccessRate_noReviews_returnsNil() {
        XCTAssertNil(model.overallSuccessRate)
    }

    func test_overallSuccessRate_allCorrect_returnsOne() {
        model.recordResult(for: card1, correct: true, fullTesting: true)
        model.recordResult(for: card2, correct: true, fullTesting: true)
        XCTAssertEqual(model.overallSuccessRate, 1.0)
    }

    func test_overallSuccessRate_mixedResults_calculatesCorrectly() {
        model.recordResult(for: card1, correct: true, fullTesting: true)
        model.recordResult(for: card1, correct: false)
        model.recordResult(for: card2, correct: true, fullTesting: true)
        model.recordResult(for: card2, correct: true, fullTesting: true)
        // 3 correct out of 4 total = 0.75
        XCTAssertEqual(model.overallSuccessRate!, 0.75, accuracy: 0.001)
    }

    // MARK: - dueCardCount

    func test_dueCardCount_allNew_returnsAll() {
        let cards = Array(testCards.prefix(3))
        XCTAssertEqual(model.dueCardCount(in: cards), 3)
    }

    func test_dueCardCount_someReviewed_returnsOnlyDue() {
        let cards = Array(testCards.prefix(3))
        // Review card1 - it becomes not due (next review in 4 hours)
        model.recordResult(for: card1, correct: true, fullTesting: true)
        // card2 and card3 are still new (due), card1 is not due
        XCTAssertEqual(model.dueCardCount(in: cards), 2)
    }

    // MARK: - masteredCardCount

    func test_masteredCardCount_noMastered_returnsZero() {
        let cards = Array(testCards.prefix(3))
        XCTAssertEqual(model.masteredCardCount(in: cards), 0)
    }

    func test_masteredCardCount_oneMastered_returnsOne() {
        let cards = Array(testCards.prefix(3))
        // Advance card1 to mastered
        for _ in 0..<8 {
            model.recordResult(for: card1, correct: true, fullTesting: true)
        }
        XCTAssertEqual(model.masteredCardCount(in: cards), 1)
    }

    // MARK: - familiarCardCount

    func test_familiarCardCount_noFamiliar_returnsZero() {
        let cards = Array(testCards.prefix(3))
        XCTAssertEqual(model.familiarCardCount(in: cards), 0)
    }

    func test_familiarCardCount_oneFamiliar1_returnsOne() {
        let cards = Array(testCards.prefix(3))
        // Advance card1 to familiar1 (5 correct answers)
        for _ in 0..<5 {
            model.recordResult(for: card1, correct: true, fullTesting: true)
        }
        XCTAssertEqual(model.srsStage(for: card1), .familiar1)
        XCTAssertEqual(model.familiarCardCount(in: cards), 1)
    }

    func test_familiarCardCount_countsBothFamiliar1AndFamiliar2() {
        let cards = Array(testCards.prefix(3))
        // card1 to familiar1 (5 correct)
        for _ in 0..<5 {
            model.recordResult(for: card1, correct: true, fullTesting: true)
        }
        // card2 to familiar2 (6 correct)
        for _ in 0..<6 {
            model.recordResult(for: card2, correct: true, fullTesting: true)
        }
        XCTAssertEqual(model.srsStage(for: card1), .familiar1)
        XCTAssertEqual(model.srsStage(for: card2), .familiar2)
        XCTAssertEqual(model.familiarCardCount(in: cards), 2)
    }

    // MARK: - cardCountByStage

    func test_cardCountByStage_allNew_returnsCorrectCounts() {
        let cards = Array(testCards.prefix(3))
        let counts = model.cardCountByStage(in: cards)
        XCTAssertEqual(counts[.new], 3)
        XCTAssertEqual(counts[.learning1], 0)
        XCTAssertEqual(counts[.mastered], 0)
    }

    func test_cardCountByStage_mixedStages_returnsCorrectCounts() {
        let cards = Array(testCards.prefix(3))
        model.recordResult(for: card1, correct: true, fullTesting: true) // -> learning1
        model.recordResult(for: card2, correct: true, fullTesting: true) // -> learning1
        model.recordResult(for: card2, correct: true, fullTesting: true) // -> learning2
        let counts = model.cardCountByStage(in: cards)
        XCTAssertEqual(counts[.new], 1)
        XCTAssertEqual(counts[.learning1], 1)
        XCTAssertEqual(counts[.learning2], 1)
    }

    // MARK: - resetAllProgress

    func test_resetAllProgress_clearsEverything() {
        model.recordResult(for: card1, correct: true, fullTesting: true)
        model.recordResult(for: card2, correct: false)
        XCTAssertEqual(model.reviewedCardCount, 2)

        model.resetAllProgress()

        XCTAssertEqual(model.reviewedCardCount, 0)
        XCTAssertEqual(model.totalReviews, 0)
        XCTAssertNil(model.overallSuccessRate)
        XCTAssertEqual(model.srsStage(for: card1), .new)
        XCTAssertEqual(model.srsStage(for: card2), .new)
        XCTAssertFalse(model.hasBeenReviewed(card1))
    }

    // MARK: - resetProgress for single card

    func test_resetProgress_singleCard_clearsOnlyThatCard() {
        model.recordResult(for: card1, correct: true, fullTesting: true)
        model.recordResult(for: card2, correct: true, fullTesting: true)

        model.resetProgress(for: card1)

        XCTAssertEqual(model.srsStage(for: card1), .new)
        XCTAssertFalse(model.hasBeenReviewed(card1))
        // card2 should be unaffected
        XCTAssertEqual(model.srsStage(for: card2), .learning1)
        XCTAssertTrue(model.hasBeenReviewed(card2))
    }

    // MARK: - recordResult sets lastReviewed and nextReviewDate

    func test_recordResult_correct_setsLastReviewed() {
        let beforeReview = Date()
        model.recordResult(for: card1, correct: true, fullTesting: true)
        let progress = model.getProgress(for: card1)
        XCTAssertNotNil(progress.lastReviewed)
        XCTAssertGreaterThanOrEqual(progress.lastReviewed!, beforeReview.addingTimeInterval(-1))
    }

    func test_recordResult_correct_setsNextReviewDate() {
        model.recordResult(for: card1, correct: true, fullTesting: true)
        let progress = model.getProgress(for: card1)
        XCTAssertNotNil(progress.nextReviewDate)
        // learning1 interval is 4 hours
        let expectedInterval: TimeInterval = 4 * 60 * 60
        let actualInterval = progress.nextReviewDate!.timeIntervalSince(progress.lastReviewed!)
        XCTAssertEqual(actualInterval, expectedInterval, accuracy: 5)
    }

    func test_recordResult_mastered_nextReviewDateIsNil() {
        for _ in 0..<8 {
            model.recordResult(for: card1, correct: true, fullTesting: true)
        }
        let progress = model.getProgress(for: card1)
        XCTAssertEqual(progress.srsStage, .mastered)
        XCTAssertNil(progress.nextReviewDate)
    }
}

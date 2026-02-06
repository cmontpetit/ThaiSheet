//
//  CardProgressTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

final class CardProgressTests: XCTestCase {

    // MARK: - SRSStage.advance()

    func test_advance_fromNew_returnsLearning1() {
        XCTAssertEqual(SRSStage.new.advance(), .learning1)
    }

    func test_advance_fromLearning1_returnsLearning2() {
        XCTAssertEqual(SRSStage.learning1.advance(), .learning2)
    }

    func test_advance_fromLearning2_returnsApprentice1() {
        XCTAssertEqual(SRSStage.learning2.advance(), .apprentice1)
    }

    func test_advance_fromApprentice1_returnsApprentice2() {
        XCTAssertEqual(SRSStage.apprentice1.advance(), .apprentice2)
    }

    func test_advance_fromApprentice2_returnsFamiliar1() {
        XCTAssertEqual(SRSStage.apprentice2.advance(), .familiar1)
    }

    func test_advance_fromFamiliar1_returnsFamiliar2() {
        XCTAssertEqual(SRSStage.familiar1.advance(), .familiar2)
    }

    func test_advance_fromFamiliar2_returnsConfident() {
        XCTAssertEqual(SRSStage.familiar2.advance(), .confident)
    }

    func test_advance_fromConfident_returnsMastered() {
        XCTAssertEqual(SRSStage.confident.advance(), .mastered)
    }

    func test_advance_fromMastered_returnsMastered() {
        XCTAssertEqual(SRSStage.mastered.advance(), .mastered)
    }

    func test_advance_fullChain_newToMastered() {
        var stage = SRSStage.new
        let expectedSequence: [SRSStage] = [
            .learning1, .learning2, .apprentice1, .apprentice2,
            .familiar1, .familiar2, .confident, .mastered
        ]
        for expected in expectedSequence {
            stage = stage.advance()
            XCTAssertEqual(stage, expected)
        }
    }

    // MARK: - SRSStage.demote()

    func test_demote_fromMastered_returnsFamiliar2() {
        XCTAssertEqual(SRSStage.mastered.demote(), .familiar2)
    }

    func test_demote_fromConfident_returnsFamiliar1() {
        XCTAssertEqual(SRSStage.confident.demote(), .familiar1)
    }

    func test_demote_fromFamiliar2_returnsApprentice2() {
        XCTAssertEqual(SRSStage.familiar2.demote(), .apprentice2)
    }

    func test_demote_fromFamiliar1_returnsApprentice1() {
        XCTAssertEqual(SRSStage.familiar1.demote(), .apprentice1)
    }

    func test_demote_fromApprentice2_returnsLearning2() {
        XCTAssertEqual(SRSStage.apprentice2.demote(), .learning2)
    }

    func test_demote_fromApprentice1_returnsLearning1() {
        XCTAssertEqual(SRSStage.apprentice1.demote(), .learning1)
    }

    func test_demote_fromLearning2_staysAtLearning1() {
        // rawValue 2 - 2 = 0, but min is learning1(1)
        XCTAssertEqual(SRSStage.learning2.demote(), .learning1)
    }

    func test_demote_fromLearning1_cannotGoBelowLearning1() {
        XCTAssertEqual(SRSStage.learning1.demote(), .learning1)
    }

    func test_demote_fromNew_goesToLearning1() {
        // new(0) - 2 = -2, clamped to learning1(1)
        XCTAssertEqual(SRSStage.new.demote(), .learning1)
    }

    // MARK: - SRSStage.intervalSeconds

    func test_intervalSeconds_new_isZero() {
        XCTAssertEqual(SRSStage.new.intervalSeconds, 0)
    }

    func test_intervalSeconds_learning1_is4Hours() {
        XCTAssertEqual(SRSStage.learning1.intervalSeconds, 4 * 60 * 60)
        XCTAssertEqual(SRSStage.learning1.intervalSeconds, 14400)
    }

    func test_intervalSeconds_learning2_is8Hours() {
        XCTAssertEqual(SRSStage.learning2.intervalSeconds, 8 * 60 * 60)
        XCTAssertEqual(SRSStage.learning2.intervalSeconds, 28800)
    }

    func test_intervalSeconds_apprentice1_is1Day() {
        XCTAssertEqual(SRSStage.apprentice1.intervalSeconds, 24 * 60 * 60)
    }

    func test_intervalSeconds_apprentice2_is2Days() {
        XCTAssertEqual(SRSStage.apprentice2.intervalSeconds, 2 * 24 * 60 * 60)
    }

    func test_intervalSeconds_familiar1_is1Week() {
        XCTAssertEqual(SRSStage.familiar1.intervalSeconds, 7 * 24 * 60 * 60)
    }

    func test_intervalSeconds_familiar2_is2Weeks() {
        XCTAssertEqual(SRSStage.familiar2.intervalSeconds, 14 * 24 * 60 * 60)
    }

    func test_intervalSeconds_confident_is1Month() {
        XCTAssertEqual(SRSStage.confident.intervalSeconds, 30 * 24 * 60 * 60)
    }

    func test_intervalSeconds_mastered_isInfinity() {
        XCTAssertEqual(SRSStage.mastered.intervalSeconds, .infinity)
    }

    // MARK: - SRSStage.displayName

    func test_displayName_allStagesHaveNonEmptyNames() {
        for stage in SRSStage.allCases {
            XCTAssertFalse(stage.displayName.isEmpty,
                           "\(stage) should have a non-empty displayName")
        }
    }

    func test_displayName_learning1And2_shareSameName() {
        XCTAssertEqual(SRSStage.learning1.displayName,
                       SRSStage.learning2.displayName)
    }

    func test_displayName_apprentice1And2_shareSameName() {
        XCTAssertEqual(SRSStage.apprentice1.displayName,
                       SRSStage.apprentice2.displayName)
    }

    func test_displayName_familiar1And2_shareSameName() {
        XCTAssertEqual(SRSStage.familiar1.displayName,
                       SRSStage.familiar2.displayName)
    }

    func test_displayName_distinctGroupsHaveDifferentNames() {
        // Each group should have a unique name
        let groupNames = [
            SRSStage.new.displayName,
            SRSStage.learning1.displayName,
            SRSStage.apprentice1.displayName,
            SRSStage.familiar1.displayName,
            SRSStage.confident.displayName,
            SRSStage.mastered.displayName,
        ]
        let uniqueNames = Set(groupNames)
        XCTAssertEqual(groupNames.count, uniqueNames.count,
                       "Each stage group should have a distinct display name")
    }

    // MARK: - SRSStage.Comparable

    func test_comparable_newIsLessThanLearning1() {
        XCTAssertTrue(SRSStage.new < .learning1)
    }

    func test_comparable_learning2IsLessThanApprentice1() {
        XCTAssertTrue(SRSStage.learning2 < .apprentice1)
    }

    func test_comparable_confidentIsLessThanMastered() {
        XCTAssertTrue(SRSStage.confident < .mastered)
    }

    func test_comparable_masteredIsNotLessThanConfident() {
        XCTAssertFalse(SRSStage.mastered < .confident)
    }

    // MARK: - CardProgress.isDue

    func test_isDue_newCard_alwaysDue() {
        let progress = CardProgress(cardId: "test")
        XCTAssertTrue(progress.isDue)
    }

    func test_isDue_masteredCard_neverDue() {
        var progress = CardProgress(cardId: "test")
        progress.srsStage = .mastered
        XCTAssertFalse(progress.isDue)
    }

    func test_isDue_withPastReviewDate_isDue() {
        var progress = CardProgress(cardId: "test")
        progress.srsStage = .learning1
        progress.nextReviewDate = Date().addingTimeInterval(-3600) // 1 hour ago
        XCTAssertTrue(progress.isDue)
    }

    func test_isDue_withFutureReviewDate_isNotDue() {
        var progress = CardProgress(cardId: "test")
        progress.srsStage = .learning1
        progress.nextReviewDate = Date().addingTimeInterval(3600) // 1 hour from now
        XCTAssertFalse(progress.isDue)
    }

    func test_isDue_withNoNextReviewDate_isDue() {
        var progress = CardProgress(cardId: "test")
        progress.srsStage = .learning1
        progress.nextReviewDate = nil
        XCTAssertTrue(progress.isDue)
    }

    // MARK: - CardProgress.successRate

    func test_successRate_noReviews_returnsNil() {
        let progress = CardProgress(cardId: "test")
        XCTAssertNil(progress.successRate)
    }

    func test_successRate_allCorrect_returnsOne() {
        var progress = CardProgress(cardId: "test")
        progress.correctCount = 5
        progress.incorrectCount = 0
        XCTAssertEqual(progress.successRate, 1.0)
    }

    func test_successRate_allIncorrect_returnsZero() {
        var progress = CardProgress(cardId: "test")
        progress.correctCount = 0
        progress.incorrectCount = 5
        XCTAssertEqual(progress.successRate, 0.0)
    }

    func test_successRate_mixedResults_calculatesCorrectly() {
        var progress = CardProgress(cardId: "test")
        progress.correctCount = 3
        progress.incorrectCount = 7
        XCTAssertEqual(progress.successRate!, 0.3, accuracy: 0.001)
    }

    func test_successRate_halfCorrect_returnsPointFive() {
        var progress = CardProgress(cardId: "test")
        progress.correctCount = 4
        progress.incorrectCount = 4
        XCTAssertEqual(progress.successRate, 0.5)
    }

    // MARK: - CardProgress.totalReviews

    func test_totalReviews_noReviews_returnsZero() {
        let progress = CardProgress(cardId: "test")
        XCTAssertEqual(progress.totalReviews, 0)
    }

    func test_totalReviews_sumOfCorrectAndIncorrect() {
        var progress = CardProgress(cardId: "test")
        progress.correctCount = 7
        progress.incorrectCount = 3
        XCTAssertEqual(progress.totalReviews, 10)
    }

    // MARK: - CardProgress.overdueSeconds

    func test_overdueSeconds_newCard_returnsZero() {
        let progress = CardProgress(cardId: "test")
        XCTAssertEqual(progress.overdueSeconds, 0)
    }

    func test_overdueSeconds_overdueCard_returnsPositive() {
        var progress = CardProgress(cardId: "test")
        progress.srsStage = .learning1
        progress.nextReviewDate = Date().addingTimeInterval(-7200) // 2 hours ago
        XCTAssertGreaterThan(progress.overdueSeconds, 7100) // approximately 7200
    }

    func test_overdueSeconds_futureCard_returnsNegative() {
        var progress = CardProgress(cardId: "test")
        progress.srsStage = .learning1
        progress.nextReviewDate = Date().addingTimeInterval(7200) // 2 hours from now
        XCTAssertLessThan(progress.overdueSeconds, 0)
    }

    // MARK: - SRSStage Codable

    func test_srsStage_codable_roundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for stage in SRSStage.allCases {
            let data = try encoder.encode(stage)
            let decoded = try decoder.decode(SRSStage.self, from: data)
            XCTAssertEqual(decoded, stage, "Round-trip failed for \(stage)")
        }
    }

    // MARK: - CardProgress Codable

    func test_cardProgress_codable_roundTrip() throws {
        var progress = CardProgress(cardId: "test-card")
        progress.correctCount = 5
        progress.incorrectCount = 2
        progress.srsStage = .familiar1
        progress.lastReviewed = Date()
        progress.nextReviewDate = Date().addingTimeInterval(7 * 24 * 60 * 60)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(progress)
        let decoded = try decoder.decode(CardProgress.self, from: data)

        XCTAssertEqual(decoded.cardId, "test-card")
        XCTAssertEqual(decoded.correctCount, 5)
        XCTAssertEqual(decoded.incorrectCount, 2)
        XCTAssertEqual(decoded.srsStage, .familiar1)
        XCTAssertNotNil(decoded.lastReviewed)
        XCTAssertNotNil(decoded.nextReviewDate)
    }

    // MARK: - SRSStage.allCases

    func test_allCases_contains9Stages() {
        XCTAssertEqual(SRSStage.allCases.count, 9)
    }

    func test_allCases_rawValuesAreSequential() {
        let rawValues = SRSStage.allCases.map(\.rawValue)
        XCTAssertEqual(rawValues, [0, 1, 2, 3, 4, 5, 6, 7, 8])
    }
}

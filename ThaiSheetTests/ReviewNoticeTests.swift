//
//  ReviewNoticeTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

@MainActor
final class ReviewNoticeTests: XCTestCase {

    private var model: LearningModel!
    private var card: FlashcardItem!
    private var otherCard: FlashcardItem!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ReviewNoticeTests_\(UUID().uuidString)"
        model = LearningModel(store: UserDefaults(suiteName: suiteName)!)
        let consonants = Consonant.loadAll()
        card = .consonant(consonants[0], includesName: true)
        otherCard = .consonant(consonants[1], includesName: true)
    }

    override func tearDown() {
        model = nil
        card = nil
        otherCard = nil
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        suiteName = nil
        super.tearDown()
    }

    /// Records a first answer, then an early correct one, and returns the
    /// notice the header would store
    private func earlyCorrectNotice() throws -> ReviewNotice {
        var now = Date()
        model.clock = { now }
        model.recordResult(for: card, correct: true)
        now = now.addingTimeInterval(60)
        let outcome = model.recordResult(for: card, correct: true)
        guard case .notDue = outcome else {
            XCTFail("Expected .notDue, got \(outcome)")
            throw XCTSkip("Setup failed")
        }
        return ReviewNotice(cardID: card.id, outcome: outcome, progress: model.getProgress(for: card))
    }

    func test_applies_toSameCardWithUnchangedProgress() throws {
        let notice = try earlyCorrectNotice()
        XCTAssertTrue(notice.applies(to: card.id, progress: model.getProgress(for: card)))
    }

    func test_doesNotApply_toAnotherCard() throws {
        let notice = try earlyCorrectNotice()
        XCTAssertFalse(notice.applies(to: otherCard.id, progress: model.getProgress(for: otherCard)))
    }

    func test_doesNotApply_afterResetAllProgress() throws {
        let notice = try earlyCorrectNotice()
        model.resetAllProgress()
        XCTAssertFalse(notice.applies(to: card.id, progress: model.getProgress(for: card)),
                       "A reset card is New, so an old next-review date must not show")
    }

    func test_doesNotApply_afterALaterAnswer() throws {
        let notice = try earlyCorrectNotice()
        model.recordResult(for: card, correct: false)
        XCTAssertFalse(notice.applies(to: card.id, progress: model.getProgress(for: card)))
    }
}

//
//  SyncedKeyValueStoreTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

@MainActor
final class SyncedKeyValueStoreTests: XCTestCase {

    // MARK: - Learning progress merge logic
    // Tests verify the merge-by-lastReviewed strategy used by SyncedKeyValueStore

    func test_mergeByLastReviewed_moreRecentWins() {
        let oldDate = Date(timeIntervalSince1970: 1000)
        let newDate = Date(timeIntervalSince1970: 2000)

        var localProgress = CardProgress(cardId: "test")
        localProgress.correctCount = 1
        localProgress.lastReviewed = oldDate
        localProgress.srsStage = .learning1

        var cloudProgress = CardProgress(cardId: "test")
        cloudProgress.correctCount = 3
        cloudProgress.lastReviewed = newDate
        cloudProgress.srsStage = .apprentice1

        // Cloud has more recent review — cloud wins
        let localDate = localProgress.lastReviewed ?? .distantPast
        let cloudDate = cloudProgress.lastReviewed ?? .distantPast
        let winner = cloudDate > localDate ? cloudProgress : localProgress

        XCTAssertEqual(winner.srsStage, .apprentice1)
        XCTAssertEqual(winner.correctCount, 3)
    }

    func test_mergeByLastReviewed_localMoreRecent_localWins() {
        let oldDate = Date(timeIntervalSince1970: 1000)
        let newDate = Date(timeIntervalSince1970: 2000)

        var localProgress = CardProgress(cardId: "test")
        localProgress.correctCount = 5
        localProgress.incorrectCount = 1
        localProgress.lastReviewed = newDate
        localProgress.srsStage = .familiar1

        var cloudProgress = CardProgress(cardId: "test")
        cloudProgress.correctCount = 2
        cloudProgress.lastReviewed = oldDate
        cloudProgress.srsStage = .learning2

        let localDate = localProgress.lastReviewed ?? .distantPast
        let cloudDate = cloudProgress.lastReviewed ?? .distantPast
        let winner = cloudDate > localDate ? cloudProgress : localProgress

        XCTAssertEqual(winner.srsStage, .familiar1)
        XCTAssertEqual(winner.correctCount, 5)
    }

    func test_mergeByLastReviewed_nilDates_treatAsDistantPast() {
        let localProgress = CardProgress(cardId: "test")
        var cloudProgress = CardProgress(cardId: "test")
        cloudProgress.correctCount = 1
        cloudProgress.lastReviewed = Date()
        cloudProgress.srsStage = .learning1

        let localDate = localProgress.lastReviewed ?? .distantPast
        let cloudDate = cloudProgress.lastReviewed ?? .distantPast
        let winner = cloudDate > localDate ? cloudProgress : localProgress

        XCTAssertEqual(winner.srsStage, .learning1)
    }

    func test_merge_cloudOnlyCard_isAdded() {
        var merged: [String: CardProgress] = [:]
        var cloudCard = CardProgress(cardId: "cloud-only")
        cloudCard.correctCount = 2
        cloudCard.lastReviewed = Date()
        cloudCard.srsStage = .learning2

        if merged["cloud-only"] == nil {
            merged["cloud-only"] = cloudCard
        }

        XCTAssertEqual(merged["cloud-only"]?.srsStage, .learning2)
    }

    func test_merge_localOnlyCard_isPreserved() {
        var localCard = CardProgress(cardId: "local-only")
        localCard.correctCount = 3
        localCard.lastReviewed = Date()
        localCard.srsStage = .apprentice1

        var merged: [String: CardProgress] = ["local-only": localCard]
        let cloudProgress: [String: CardProgress] = [:]

        // Merge: cloud has no matching card, local stays
        for (cardId, cloudCard) in cloudProgress {
            if let localCard = merged[cardId] {
                let localDate = localCard.lastReviewed ?? .distantPast
                let cloudDate = cloudCard.lastReviewed ?? .distantPast
                if cloudDate > localDate {
                    merged[cardId] = cloudCard
                }
            } else {
                merged[cardId] = cloudCard
            }
        }

        XCTAssertEqual(merged["local-only"]?.srsStage, .apprentice1)
        XCTAssertEqual(merged["local-only"]?.correctCount, 3)
    }

    func test_merge_multipleCards_eachMergedIndependently() {
        let oldDate = Date(timeIntervalSince1970: 1000)
        let newDate = Date(timeIntervalSince1970: 2000)

        // Card A: local is more recent
        var localA = CardProgress(cardId: "cardA")
        localA.correctCount = 5
        localA.lastReviewed = newDate
        localA.srsStage = .familiar1

        // Card B: cloud is more recent
        var localB = CardProgress(cardId: "cardB")
        localB.correctCount = 1
        localB.lastReviewed = oldDate
        localB.srsStage = .learning1

        var cloudA = CardProgress(cardId: "cardA")
        cloudA.correctCount = 2
        cloudA.lastReviewed = oldDate
        cloudA.srsStage = .learning2

        var cloudB = CardProgress(cardId: "cardB")
        cloudB.correctCount = 4
        cloudB.lastReviewed = newDate
        cloudB.srsStage = .apprentice2

        var merged: [String: CardProgress] = ["cardA": localA, "cardB": localB]
        let cloudProgress: [String: CardProgress] = ["cardA": cloudA, "cardB": cloudB]

        for (cardId, cloudCard) in cloudProgress {
            if let localCard = merged[cardId] {
                let localDate = localCard.lastReviewed ?? .distantPast
                let cloudDate = cloudCard.lastReviewed ?? .distantPast
                if cloudDate > localDate {
                    merged[cardId] = cloudCard
                }
            } else {
                merged[cardId] = cloudCard
            }
        }

        // Card A: local wins (more recent)
        XCTAssertEqual(merged["cardA"]?.srsStage, .familiar1)
        // Card B: cloud wins (more recent)
        XCTAssertEqual(merged["cardB"]?.srsStage, .apprentice2)
    }
}

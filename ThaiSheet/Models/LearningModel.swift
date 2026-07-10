//
//  LearningModel.swift
//  ThaiSheet
//

import Foundation
import SwiftUI
import os

// MARK: - Environment Key

private struct LearningModelKey: EnvironmentKey {
    static let defaultValue = LearningModel()
}

extension EnvironmentValues {
    var learningModel: LearningModel {
        get { self[LearningModelKey.self] }
        set { self[LearningModelKey.self] = newValue }
    }
}

/// Tracks learning progress for all flashcards using Wanikani-style SRS
@Observable
class LearningModel {
    static let storageKey = "learningProgress"
    private static let logger = Logger(subsystem: "net.montpetit.thaisheet", category: "LearningModel")

    /// Progress data keyed by card ID
    private var progressByCardId: [String: CardProgress] = [:]

    private let store: KeyValueStore

    init(store: KeyValueStore = UserDefaults.standard) {
        self.store = store
        load()
    }

    // MARK: - Public API

    /// Maximum stage allowed for partial testing (capped at Familiar 2)
    private static let partialTestingMaxStage: SRSStage = .familiar2

    /// Record a result for a card using Wanikani-style SRS
    /// - Parameters:
    ///   - card: The flashcard item
    ///   - correct: Whether the answer was correct
    ///   - fullTesting: If false, advancement is capped at Familiar 2 (can't reach Confident/Mastered)
    func recordResult(for card: FlashcardItem, correct: Bool, fullTesting: Bool = true) {
        var progress = progressByCardId[card.id] ?? CardProgress(cardId: card.id)

        if correct {
            progress.correctCount += 1
            var newStage = progress.srsStage.advance()

            // Cap advancement for partial testing
            if !fullTesting && newStage > LearningModel.partialTestingMaxStage {
                newStage = LearningModel.partialTestingMaxStage
            }

            progress.srsStage = newStage
        } else {
            progress.incorrectCount += 1
            progress.srsStage = progress.srsStage.demote()
        }

        progress.lastReviewed = Date()

        // Calculate next review date based on new stage
        if progress.srsStage == .mastered {
            progress.nextReviewDate = nil  // Never review again
        } else {
            progress.nextReviewDate = Date().addingTimeInterval(progress.srsStage.intervalSeconds)
        }

        progressByCardId[card.id] = progress
        save()
    }

    /// Get progress for a specific card
    func getProgress(for card: FlashcardItem) -> CardProgress {
        progressByCardId[card.id] ?? CardProgress(cardId: card.id)
    }

    /// Get progress for a card by ID
    func getProgress(forId cardId: String) -> CardProgress {
        progressByCardId[cardId] ?? CardProgress(cardId: cardId)
    }

    /// Check if a card has ever been reviewed
    func hasBeenReviewed(_ card: FlashcardItem) -> Bool {
        guard let progress = progressByCardId[card.id] else { return false }
        return progress.totalReviews > 0
    }

    /// Check if a card is due for review
    func isDue(_ card: FlashcardItem) -> Bool {
        getProgress(for: card).isDue
    }

    /// Get the SRS stage for a card
    func srsStage(for card: FlashcardItem) -> SRSStage {
        getProgress(for: card).srsStage
    }

    // MARK: - Statistics

    /// Total number of cards that have been reviewed at least once
    var reviewedCardCount: Int {
        progressByCardId.values.filter { $0.totalReviews > 0 }.count
    }

    /// Total number of reviews across all cards
    var totalReviews: Int {
        progressByCardId.values.reduce(0) { $0 + $1.totalReviews }
    }

    /// Overall success rate across all reviews
    var overallSuccessRate: Double? {
        let total = progressByCardId.values.reduce(0) { $0 + $1.totalReviews }
        guard total > 0 else { return nil }
        let correct = progressByCardId.values.reduce(0) { $0 + $1.correctCount }
        return Double(correct) / Double(total)
    }

    /// Count of cards at each SRS stage (for statistics display)
    func cardCountByStage(in cards: [FlashcardItem]) -> [SRSStage: Int] {
        var counts: [SRSStage: Int] = [:]
        for stage in SRSStage.allCases {
            counts[stage] = 0
        }
        for card in cards {
            let stage = getProgress(for: card).srsStage
            counts[stage, default: 0] += 1
        }
        return counts
    }

    /// Count of cards due for review
    func dueCardCount(in cards: [FlashcardItem]) -> Int {
        cards.filter { isDue($0) }.count
    }

    /// Count of mastered cards
    func masteredCardCount(in cards: [FlashcardItem]) -> Int {
        cards.filter { srsStage(for: $0) == .mastered }.count
    }

    /// Count of cards at familiar stage (familiar1 or familiar2)
    func familiarCardCount(in cards: [FlashcardItem]) -> Int {
        cards.filter {
            let stage = srsStage(for: $0)
            return stage == .familiar1 || stage == .familiar2
        }.count
    }

    // MARK: - Reset

    /// Clear all learning progress
    func resetAllProgress() {
        progressByCardId.removeAll()
        save()
    }

    /// Clear progress for a specific card
    func resetProgress(for card: FlashcardItem) {
        progressByCardId.removeValue(forKey: card.id)
        save()
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(progressByCardId)
            store.set(data, forKey: LearningModel.storageKey)
        } catch {
            Self.logger.error("Failed to encode learning progress: \(error, privacy: .public)")
            assertionFailure("Failed to encode learning progress: \(error)")
        }
    }

    private func load() {
        guard let data = store.data(forKey: LearningModel.storageKey) else {
            return
        }
        let decoder = JSONDecoder()
        do {
            progressByCardId = try decoder.decode([String: CardProgress].self, from: data)
        } catch {
            // Keep the in-memory progress (empty on first load) rather than
            // overwriting the stored blob; the user's data may be recoverable
            // by a newer build that understands the format.
            Self.logger.error("Failed to decode stored learning progress; leaving store untouched: \(error, privacy: .public)")
            assertionFailure("Failed to decode stored learning progress: \(error)")
        }
    }

    /// Reload progress from the store (called when external sync updates arrive)
    func reload() {
        load()
    }
}

//
//  LearningModel.swift
//  ThaiSheet
//

import Foundation

/// Tracks learning progress for all flashcards, persisted to UserDefaults
@Observable
class LearningModel {
    private static let storageKey = "learningProgress"

    /// Progress data keyed by card ID
    private var progressByCardId: [String: CardProgress] = [:]

    init() {
        load()
    }

    // MARK: - Public API

    /// Record a result for a card
    func recordResult(for card: FlashcardItem, correct: Bool) {
        var progress = progressByCardId[card.id] ?? CardProgress(cardId: card.id)

        if correct {
            progress.correctCount += 1
        } else {
            progress.incorrectCount += 1
        }
        progress.lastReviewed = Date()

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

    /// Get selection weight for a card (for intelligent strategy)
    func selectionWeight(for card: FlashcardItem) -> Double {
        getProgress(for: card).selectionWeight
    }

    /// Check if a card has ever been reviewed
    func hasBeenReviewed(_ card: FlashcardItem) -> Bool {
        guard let progress = progressByCardId[card.id] else { return false }
        return progress.totalReviews > 0
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
        if let data = try? encoder.encode(progressByCardId) {
            UserDefaults.standard.set(data, forKey: LearningModel.storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: LearningModel.storageKey) else {
            return
        }
        let decoder = JSONDecoder()
        if let loaded = try? decoder.decode([String: CardProgress].self, from: data) {
            progressByCardId = loaded
        }
    }
}

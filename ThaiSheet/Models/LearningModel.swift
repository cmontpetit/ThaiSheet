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
    /// Where an undecodable progress blob is preserved before being overwritten
    static let corruptedBackupKey = "learningProgress.corrupted-backup"
    /// Where an undecodable cloud blob is preserved during reconciliation
    static let corruptedCloudBackupKey = "learningProgress.corrupted-cloud-backup"
    private static let logger = Logger(subsystem: "net.montpetit.thaisheet", category: "LearningModel")

    /// Set when the stored blob exists but can't be decoded; save() preserves
    /// the blob under corruptedBackupKey before first overwriting it
    @ObservationIgnored private var hasUndecodableStoredProgress = false

    /// Progress data keyed by card ID
    private var progressByCardId: [String: CardProgress] = [:]

    private let store: KeyValueStore

    init(store: KeyValueStore = UserDefaults.standard) {
        self.store = store
        load()
    }

    #if compiler(>=6.2)
    /// This model has no actor-isolated cleanup. Keeping destruction nonisolated
    /// avoids the back-deployed MainActor deinit thunk used by newer toolchains,
    /// which crashes when short-lived instances are released in iOS 17 tests.
    nonisolated deinit {}
    #endif

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
        // A save after a failed load would overwrite the very blob load()
        // chose to preserve — move it to the backup key first, so it stays
        // recoverable by a newer build that understands the format
        if hasUndecodableStoredProgress {
            if let corrupted = store.data(forKey: LearningModel.storageKey) {
                store.set(corrupted, forKey: LearningModel.corruptedBackupKey)
                Self.logger.error("Preserved undecodable learning progress under \(LearningModel.corruptedBackupKey, privacy: .public)")
            }
            hasUndecodableStoredProgress = false
        }
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
            hasUndecodableStoredProgress = false
        } catch {
            hasUndecodableStoredProgress = true
            Self.logger.error("Failed to decode stored learning progress; blob will be backed up before any overwrite: \(error, privacy: .public)")
        }
    }

    /// Reload progress from the store (called when external sync updates arrive)
    func reload() {
        load()
    }

    #if DEBUG
    /// Marks one card as successfully completed without persisting fake progress.
    func seedScreenshotCompletion(for card: FlashcardItem) {
        progressByCardId[card.id] = CardProgress(
            cardId: card.id,
            correctCount: 1,
            incorrectCount: 0,
            lastReviewed: Date(),
            srsStage: .learning1,
            nextReviewDate: Date().addingTimeInterval(SRSStage.learning1.intervalSeconds)
        )
    }

    /// Populates a deterministic, in-memory distribution for App Store screenshots.
    /// It deliberately does not save, so no fake progress can reach user storage.
    func seedScreenshotProgress(for cards: [FlashcardItem]) {
        let stages: [SRSStage] = [
            .new, .new, .new, .new, .new, .new,
            .learning1, .learning2, .learning2,
            .apprentice1, .apprentice1, .apprentice2, .apprentice2,
            .familiar1, .familiar1, .familiar2,
            .confident, .confident,
            .mastered, .mastered,
        ]

        var seeded: [String: CardProgress] = [:]
        for (index, card) in cards.enumerated() {
            let stage = stages[index % stages.count]
            let reviewed = stage != .new
            let correct = reviewed ? 4 + (index % 9) : 0
            let incorrect = reviewed ? index % 3 : 0
            let isDue = reviewed && stage != .mastered && index.isMultiple(of: 3)

            seeded[card.id] = CardProgress(
                cardId: card.id,
                correctCount: correct,
                incorrectCount: incorrect,
                lastReviewed: reviewed ? Date().addingTimeInterval(-86_400) : nil,
                srsStage: stage,
                nextReviewDate: stage == .mastered || !reviewed
                    ? nil
                    : Date().addingTimeInterval(isDue ? -3_600 : 86_400)
            )
        }
        progressByCardId = seeded
    }
    #endif
}

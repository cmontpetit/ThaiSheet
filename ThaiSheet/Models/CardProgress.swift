//
//  CardProgress.swift
//  ThaiSheet
//

import Foundation

/// Tracks learning progress for a single flashcard
struct CardProgress: Codable {
    /// Unique identifier matching FlashcardItem.id
    let cardId: String

    /// Number of times answered correctly
    var correctCount: Int = 0

    /// Number of times answered incorrectly
    var incorrectCount: Int = 0

    /// Last time this card was reviewed
    var lastReviewed: Date?

    /// Total number of reviews
    var totalReviews: Int {
        correctCount + incorrectCount
    }

    /// Success rate (0.0 to 1.0), nil if never reviewed
    var successRate: Double? {
        guard totalReviews > 0 else { return nil }
        return Double(correctCount) / Double(totalReviews)
    }

    /// Weight for card selection (higher = more likely to be shown)
    /// New cards get medium weight, struggling cards get high weight
    var selectionWeight: Double {
        guard let rate = successRate else {
            // New card: medium priority
            return 0.5
        }
        // Struggling cards (low success rate) get higher weight
        // Mastered cards still have small weight to occasionally appear
        return max(0.1, 1.0 - rate)
    }
}

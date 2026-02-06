//
//  CardProgress.swift
//  ThaiSheet
//

import Foundation

/// Wanikani-style SRS stages with their review intervals
enum SRSStage: Int, Codable, CaseIterable, Comparable {
    case new = 0           // Never reviewed - immediate
    case learning1 = 1     // 4 hours
    case learning2 = 2     // 8 hours
    case apprentice1 = 3   // 1 day
    case apprentice2 = 4   // 2 days
    case familiar1 = 5     // 1 week
    case familiar2 = 6     // 2 weeks
    case confident = 7     // 1 month
    case mastered = 8      // Permanently learned - never shown again

    static func < (lhs: SRSStage, rhs: SRSStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Human-readable name for the stage
    var displayName: String {
        switch self {
        case .new: return String(localized: "New")
        case .learning1, .learning2: return String(localized: "Learning")
        case .apprentice1, .apprentice2: return String(localized: "Apprentice")
        case .familiar1, .familiar2: return String(localized: "Familiar")
        case .confident: return String(localized: "Confident")
        case .mastered: return String(localized: "Mastered")
        }
    }

    /// Interval in seconds until next review
    var intervalSeconds: TimeInterval {
        switch self {
        case .new: return 0                          // Immediate
        case .learning1: return 4 * 60 * 60          // 4 hours
        case .learning2: return 8 * 60 * 60          // 8 hours
        case .apprentice1: return 24 * 60 * 60       // 1 day
        case .apprentice2: return 2 * 24 * 60 * 60   // 2 days
        case .familiar1: return 7 * 24 * 60 * 60     // 1 week
        case .familiar2: return 14 * 24 * 60 * 60    // 2 weeks
        case .confident: return 30 * 24 * 60 * 60    // ~1 month
        case .mastered: return .infinity             // Never
        }
    }

    /// Advance to next stage (on correct answer)
    func advance() -> SRSStage {
        guard let next = SRSStage(rawValue: rawValue + 1) else {
            return .mastered
        }
        return next
    }

    /// Drop back stages (on incorrect answer) - drops 2 stages, minimum learning1
    func demote() -> SRSStage {
        let newRaw = max(SRSStage.learning1.rawValue, rawValue - 2)
        return SRSStage(rawValue: newRaw) ?? .learning1
    }
}

/// Tracks learning progress for a single flashcard using Wanikani-style SRS
struct CardProgress: Codable {
    /// Unique identifier matching FlashcardItem.id
    let cardId: String

    /// Number of times answered correctly
    var correctCount: Int = 0

    /// Number of times answered incorrectly
    var incorrectCount: Int = 0

    /// Last time this card was reviewed
    var lastReviewed: Date?

    /// Current SRS stage
    var srsStage: SRSStage = .new

    /// When the card is next due for review
    var nextReviewDate: Date?

    /// Total number of reviews
    var totalReviews: Int {
        correctCount + incorrectCount
    }

    /// Success rate (0.0 to 1.0), nil if never reviewed
    var successRate: Double? {
        guard totalReviews > 0 else { return nil }
        return Double(correctCount) / Double(totalReviews)
    }

    /// Whether this card is due for review (or overdue)
    var isDue: Bool {
        // Mastered cards are never due
        guard srsStage != .mastered else { return false }

        // New cards are always due
        guard let nextReview = nextReviewDate else { return true }

        return Date() >= nextReview
    }

    /// How overdue the card is (negative = not yet due)
    var overdueSeconds: TimeInterval {
        guard let nextReview = nextReviewDate else {
            // New cards: very overdue to prioritize them
            return 0
        }
        return Date().timeIntervalSince(nextReview)
    }
}

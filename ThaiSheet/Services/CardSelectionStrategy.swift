//
//  CardSelectionStrategy.swift
//  ThaiSheet
//

import Foundation

/// Protocol for card selection strategies
protocol CardSelectionStrategy: AnyObject {
    /// The current card to display
    var currentCard: FlashcardItem? { get }

    /// Move to the next card
    func nextCard()

    /// Move to the previous card
    func previousCard()

    /// Reset to initial state
    func reset()

    /// Update with new filtered cards and learning model
    func update(cards: [FlashcardItem], learningModel: LearningModel)
}

// MARK: - Sequential Strategy

/// Cycles through cards in order (current behavior)
@Observable
class SequentialStrategy: CardSelectionStrategy {
    private var cards: [FlashcardItem] = []
    private var currentIndex: Int = 0

    var currentCard: FlashcardItem? {
        guard !cards.isEmpty else { return nil }
        let safeIndex = currentIndex % cards.count
        return cards[safeIndex]
    }

    func nextCard() {
        guard !cards.isEmpty else { return }
        currentIndex = (currentIndex + 1) % cards.count
    }

    func previousCard() {
        guard !cards.isEmpty else { return }
        currentIndex = (currentIndex - 1 + cards.count) % cards.count
    }

    func reset() {
        currentIndex = 0
    }

    func update(cards: [FlashcardItem], learningModel: LearningModel) {
        self.cards = cards
        // Keep index valid
        if !cards.isEmpty && currentIndex >= cards.count {
            currentIndex = 0
        }
    }

    /// Jump to a specific index (for FlashcardManager.jumpTo)
    func jumpTo(index: Int) {
        guard !cards.isEmpty else { return }
        currentIndex = max(0, min(index, cards.count - 1))
    }

    /// Find index of a card by ID
    func indexOf(cardId: String) -> Int? {
        cards.firstIndex(where: { $0.id == cardId })
    }
}

// MARK: - Wanikani Strategy

/// Selects cards using Wanikani-style SRS: prioritizes due cards, then new cards
@Observable
class WanikaniStrategy: CardSelectionStrategy {
    private var cards: [FlashcardItem] = []
    private var learningModel: LearningModel?
    private var current: FlashcardItem?

    /// History of shown cards for "previous" navigation
    private var history: [FlashcardItem] = []
    private var historyIndex: Int = -1

    var currentCard: FlashcardItem? {
        current
    }

    func nextCard() {
        guard !cards.isEmpty else { return }

        // If navigating forward from history, use history
        if historyIndex >= 0 && historyIndex < history.count - 1 {
            historyIndex += 1
            current = history[historyIndex]
            return
        }

        // Select next card using SRS logic
        let next = selectSRSCard()
        current = next

        // Add to history
        if let next = next {
            history.append(next)
            historyIndex = history.count - 1
        }

        // Limit history size
        if history.count > 100 {
            history.removeFirst(50)
            historyIndex = max(0, historyIndex - 50)
        }
    }

    func previousCard() {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        current = history[historyIndex]
    }

    func reset() {
        history.removeAll()
        historyIndex = -1
        current = nil
        // Immediately select first card
        if !cards.isEmpty {
            nextCard()
        }
    }

    func update(cards: [FlashcardItem], learningModel: LearningModel) {
        self.cards = cards
        self.learningModel = learningModel

        // If no current card, select one
        if current == nil && !cards.isEmpty {
            nextCard()
        }

        // If current card is no longer in filtered list, select new one
        if let current = current, !cards.contains(where: { $0.id == current.id }) {
            self.current = nil
            nextCard()
        }
    }

    /// Select a card using Wanikani-style SRS prioritization
    private func selectSRSCard() -> FlashcardItem? {
        guard !cards.isEmpty, let model = learningModel else {
            return cards.first
        }

        // Categorize cards
        var dueCards: [(card: FlashcardItem, overdueSeconds: TimeInterval)] = []
        var newCards: [FlashcardItem] = []
        var futureCards: [(card: FlashcardItem, nextReview: Date)] = []

        for card in cards {
            let progress = model.getProgress(for: card)

            // Skip mastered cards
            if progress.srsStage == .mastered {
                continue
            }

            if progress.srsStage == .new {
                newCards.append(card)
            } else if progress.isDue {
                dueCards.append((card, progress.overdueSeconds))
            } else if let nextReview = progress.nextReviewDate {
                futureCards.append((card, nextReview))
            }
        }

        // Priority 1: Due cards (most overdue first, with some randomness)
        if !dueCards.isEmpty {
            // Sort by most overdue, then pick randomly from top candidates
            let sorted = dueCards.sorted { $0.overdueSeconds > $1.overdueSeconds }
            // Pick from top 3 most overdue (adds variety)
            let topCount = min(3, sorted.count)
            let topCards = Array(sorted.prefix(topCount))
            return topCards.randomElement()?.card
        }

        // Priority 2: New cards (random selection to introduce variety)
        if !newCards.isEmpty {
            return newCards.randomElement()
        }

        // Priority 3: Future cards (show soonest upcoming, but only if nothing else available)
        if !futureCards.isEmpty {
            let sorted = futureCards.sorted { $0.nextReview < $1.nextReview }
            return sorted.first?.card
        }

        // Fallback: all cards are mastered, show random from full list
        return cards.randomElement()
    }

    /// Jump to a specific card (for FlashcardManager.jumpTo)
    func jumpTo(card: FlashcardItem) {
        current = card
        history.append(card)
        historyIndex = history.count - 1
    }
}

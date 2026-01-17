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

// MARK: - Intelligent Strategy

/// Selects cards based on learning progress using weighted random selection
@Observable
class IntelligentStrategy: CardSelectionStrategy {
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

        // Select next card using weighted random
        let next = selectWeightedCard()
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

    /// Select a card using weighted random selection
    private func selectWeightedCard() -> FlashcardItem? {
        guard !cards.isEmpty, let model = learningModel else {
            return cards.first
        }

        // Build weights
        var weights: [Double] = []
        for card in cards {
            weights.append(model.selectionWeight(for: card))
        }

        // Calculate total weight
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else {
            return cards.randomElement()
        }

        // Random selection
        var randomValue = Double.random(in: 0..<totalWeight)
        for (index, weight) in weights.enumerated() {
            randomValue -= weight
            if randomValue <= 0 {
                return cards[index]
            }
        }

        return cards.last
    }

    /// Jump to a specific card (for FlashcardManager.jumpTo)
    func jumpTo(card: FlashcardItem) {
        current = card
        history.append(card)
        historyIndex = history.count - 1
    }
}

//
//  CardSelectionStrategy.swift
//  ThaiSheet
//

import Foundation

/// How the Flashcards tab presents the active deck (`FlashcardSettings.selectionMode`).
/// The raw values are persisted and synced: never rename one.
enum SelectionMode: String, CaseIterable {
    /// Wanikani-style SRS: due cards, then new cards, then upcoming ones
    case smart
    /// The deck's fixed order
    case sequential
    /// Each card once per pass in random order, then retry rounds for misses
    case shuffled
}

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

// MARK: - Shuffled Strategy

/// Deals the active deck once per pass in a fresh random order, then offers
/// follow-up rounds from the summary.
///
/// Grading: a card's first answer is recorded to SRS (`noteAnswer` returns
/// true for it) and is final for the round: it decides the Correct/Missed
/// counts. It can come from the pass or from answering skipped cards. Repeat
/// answers, retries, and practice of missed cards are practice only. A card
/// passed without an answer stays skipped.
@Observable
final class ShuffledStrategy: CardSelectionStrategy {
    enum Phase: Equatable {
        /// The full deck, graded
        case pass
        /// Cards skipped so far, graded: finishes the pass
        case skipped
        /// Missed cards not yet answered correctly, practice only
        case retry
        /// Every missed card again, practice only, once nothing is left to retry
        case practice
        case summary

        /// Whether a card's first answer in this phase is recorded
        var isGraded: Bool { self == .pass || self == .skipped }
    }

    /// Where every card of the deck ended up. Correct + missed + skipped is the
    /// deck size. A skipped card moves to correct or missed once answered;
    /// a first answer never changes.
    struct Summary: Equatable {
        let correct: Int
        let missed: Int
        let skipped: Int
        let leftToRetry: Int

        /// Practice missed again: offered once nothing is left to retry
        var canPracticeMissed: Bool { missed > 0 && leftToRetry == 0 }
    }

    struct Position: Equatable {
        /// 1-based position in the current round
        let number: Int
        let count: Int
        let phase: Phase
    }

    private var cards: [FlashcardItem] = []
    private var order: [FlashcardItem] = []
    private var index = 0
    private(set) var phase: Phase = .pass

    /// Card id → whether its first answer was correct. Final for the round.
    private var firstAnswers: [String: Bool] = [:]
    /// Missed cards not yet answered correctly in a retry round
    private var pendingRetry: Set<String> = []
    /// Cards answered correctly in the current retry round. Final for the round,
    /// so going back to one and missing it or swiping past it keeps it cleared.
    private var clearedThisRetry: Set<String> = []

    @ObservationIgnored private var generator: AnyRandomNumberGenerator

    init(generator: some RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.generator = AnyRandomNumberGenerator(generator)
    }

    #if compiler(>=6.2)
    /// See `FlashcardSettings`: avoids the back-deployed MainActor deinit thunk.
    nonisolated deinit {}
    #endif

    var currentCard: FlashcardItem? {
        guard phase != .summary, order.indices.contains(index) else { return nil }
        return order[index]
    }

    /// Where the current card sits in its round; nil on the summary
    var position: Position? {
        guard currentCard != nil else { return nil }
        return Position(number: index + 1, count: order.count, phase: phase)
    }

    /// The round summary, shown once a pass or follow-up round has ended
    var summary: Summary? {
        guard phase == .summary else { return nil }
        let missed = firstAnswers.values.filter { !$0 }.count
        return Summary(
            correct: firstAnswers.count - missed,
            missed: missed,
            skipped: skippedCards.count,
            leftToRetry: pendingRetry.count
        )
    }

    func nextCard() {
        guard phase != .summary, !order.isEmpty else { return }
        if index < order.count - 1 {
            index += 1
        } else {
            finishRound()
        }
    }

    func previousCard() {
        guard phase != .summary, index > 0 else { return }
        index -= 1
    }

    func reset() {
        startNewRound()
    }

    func update(cards: [FlashcardItem], learningModel: LearningModel) {
        let deckChanged = cards.map(\.id) != self.cards.map(\.id)
        self.cards = cards
        if deckChanged {
            startNewRound()
        }
    }

    /// Notes an answer to the current card and returns whether it should be
    /// recorded to SRS: true only for a card's first answer.
    func noteAnswer(cardId: String, correct: Bool) -> Bool {
        guard currentCard?.id == cardId else { return false }
        switch phase {
        case .pass, .skipped:
            guard firstAnswers[cardId] == nil else { return false }
            firstAnswers[cardId] = correct
            if !correct {
                pendingRetry.insert(cardId)
            }
            return true
        case .retry:
            if correct {
                clearedThisRetry.insert(cardId)
            }
            return false
        case .practice, .summary:
            return false
        }
    }

    /// Deals the cards still waiting for a retry in a fresh random order.
    func startRetry() {
        start(.retry, with: pendingRetry)
    }

    /// Deals the cards passed without an answer; their first answers are graded.
    func startSkipped() {
        start(.skipped, with: Set(skippedCards.map(\.id)))
    }

    /// Deals every missed card again for practice once nothing is left to retry.
    /// Answers change nothing: the summary comes back as it was.
    func startPracticeMissed() {
        guard summary?.canPracticeMissed == true else { return }
        start(.practice, with: Set(firstAnswers.filter { !$0.value }.map(\.key)))
    }

    /// Reshuffles the full deck and starts a new graded pass.
    func startNewRound() {
        order = cards.shuffled(using: &generator)
        index = 0
        phase = .pass
        firstAnswers = [:]
        pendingRetry = []
        clearedThisRetry = []
    }

    private var skippedCards: [FlashcardItem] {
        cards.filter { firstAnswers[$0.id] == nil }
    }

    private func start(_ next: Phase, with ids: Set<String>) {
        guard phase == .summary, !ids.isEmpty else { return }
        order = cards.filter { ids.contains($0.id) }.shuffled(using: &generator)
        index = 0
        clearedThisRetry = []
        phase = next
    }

    private func finishRound() {
        if phase == .retry {
            pendingRetry.subtract(clearedThisRetry)
            clearedThisRetry = []
        }
        phase = .summary
    }
}

/// Type-erased generator, so tests can inject a seeded one.
struct AnyRandomNumberGenerator: RandomNumberGenerator {
    private var base: any RandomNumberGenerator

    init(_ base: some RandomNumberGenerator) {
        self.base = base
    }

    mutating func next() -> UInt64 {
        base.next()
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

        // Add to history. Selection can legitimately return the card already
        // showing — it may be the last card still being learned — and recording
        // that again would make "previous" step back through a run of identical
        // entries, looking unresponsive. Coalesce consecutive repeats instead.
        if let next = next {
            if history.last?.id != next.id {
                history.append(next)
            }
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

        // Categorize cards, excluding the current card to ensure we show a different one
        var dueCards: [(card: FlashcardItem, overdueSeconds: TimeInterval)] = []
        var newCards: [FlashcardItem] = []
        var futureCards: [(card: FlashcardItem, nextReview: Date)] = []

        for card in cards {
            // Skip the current card to ensure navigation shows a different card
            if card.id == current?.id {
                continue
            }

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

        // Fallback: every non-current card fell out of the buckets above, which
        // means they are all mastered (or the current card is the only card).
        // A mastered card is documented as never shown again, so never resurface
        // one while any non-mastered card remains.
        let otherCards = cards.filter { $0.id != current?.id }
        let nonMasteredOthers = otherCards.filter {
            model.getProgress(for: $0).srsStage != .mastered
        }
        if let card = nonMasteredOthers.randomElement() {
            return card
        }

        // No non-mastered alternative exists. Prefer staying on the current card
        // (it may be the last card still being learned) over jumping to mastered
        // content. Only when there is no current card at all — a fresh selection
        // where the entire deck is mastered — do we surface a mastered card so the
        // UI has something to show. This is the documented all-mastered behavior.
        return current ?? otherCards.randomElement()
    }

    /// Jump to a specific card (for FlashcardManager.jumpTo)
    func jumpTo(card: FlashcardItem) {
        current = card
        history.append(card)
        historyIndex = history.count - 1
    }
}

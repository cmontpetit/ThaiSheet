//
//  FlashcardManager.swift
//  ThaiSheet
//

import Foundation
import SwiftUI

@Observable
class FlashcardManager {
    // Shared bundled data
    let data: ThaiDataStore

    // Settings reference
    let settings: FlashcardSettings

    // Learning model (shared, tracks progress)
    let learningModel: LearningModel

    // Selection strategies
    private let sequentialStrategy = SequentialStrategy()
    private let wanikaniStrategy = WanikaniStrategy()
    private let shuffledStrategy: ShuffledStrategy

    // Override card (shown once when jumping from Reference, clears on navigation)
    private var overrideCard: FlashcardItem? = nil

    /// Identifies the current quiz attempt, independently of the card's progress key.
    private(set) var attempt = 0

    /// Current active strategy based on settings
    private var activeStrategy: CardSelectionStrategy {
        switch settings.selectionMode {
        case .smart: wanikaniStrategy
        case .sequential: sequentialStrategy
        case .shuffled: shuffledStrategy
        }
    }

    private var isShuffled: Bool { settings.selectionMode == .shuffled }

    var isLoaded: Bool {
        data.isLoaded
    }

    /// The deck settings `filteredCards` was built from.
    @ObservationIgnored private var appliedSettings: FlashcardSettings.DeckSettings

    init(
        settings: FlashcardSettings,
        learningModel: LearningModel,
        data: ThaiDataStore,
        shuffledStrategy: ShuffledStrategy = ShuffledStrategy()
    ) {
        self.settings = settings
        self.learningModel = learningModel
        self.data = data
        self.shuffledStrategy = shuffledStrategy
        appliedSettings = settings.deckSettings
        filteredCards = buildDeck()
        updateStrategies()
    }

    // MARK: - Book Chapter Scope

    /// The chapter scope from settings; Off when the mapping failed to load.
    var bookScope: BookScope {
        BookScope(settings: settings, map: data.bookChapters)
    }

    /// Whether the book has introduced this card's content by the chosen chapter.
    func isInBookScope(_ item: FlashcardItem) -> Bool {
        let scope = bookScope
        guard scope.isActive, let map = data.bookChapters else { return true }
        switch item {
        case .consonant(let consonant, _):
            return scope.includes(map.placement(of: consonant))
        case .vowel(let card):
            return isCardInScope(card, duration: card.shownDuration)
        case .toneMark(let card):
            return scope.includes(map.placement(of: card))
        case .toneRule(let card):
            return scope.includes(map.placement(of: card.rule, sample: card.sample))
        case .cluster(let cluster):
            return scope.includes(map.placement(of: cluster))
        }
    }

    /// SRS cap for a card, judged against the applied deck (`QuestionCap`).
    /// The lock icon and grading both use this.
    func isPartialTesting(_ card: FlashcardItem) -> Bool {
        QuestionCap.isCapped(card, deck: filteredCards)
    }

    /// Update both strategies with the applied deck
    private func updateStrategies() {
        let cards = filteredCards
        sequentialStrategy.update(cards: cards, learningModel: learningModel)
        wanikaniStrategy.update(cards: cards, learningModel: learningModel)
        shuffledStrategy.update(cards: cards, learningModel: learningModel)
    }

    // MARK: - Filtered Cards

    /// The applied deck: the cards that matched the settings and chapter scope
    /// at the last `syncDeck()`, in order. Both strategies, the position count,
    /// the stats sheet and the SRS cap read this one snapshot.
    private(set) var filteredCards: [FlashcardItem] = []

    private func buildDeck() -> [FlashcardItem] {
        filterCardsBySettings().filter(isInBookScope)
    }

    /// The duration a vowel card presents. A card for a form shared by both
    /// durations (เกิ-) stands for both slots: it uses its own slot when that
    /// passes, else the other one. One slot decides the duration filter, the
    /// chapter scope, and the example together; the progress id and both
    /// accepted durations never change. `checkingFilters` is false for a card
    /// opened from Reference, which Filters do not gate.
    private func vowelSlot(for card: VowelCard, checkingFilters: Bool) -> VowelCard.VowelDuration? {
        let other: VowelCard.VowelDuration = card.duration == .short ? .long : .short
        let candidates = card.acceptsBothDurations ? [card.duration, other] : [card.duration]
        return candidates.first { duration in
            (!checkingFilters || settings.isVowelCardEnabled(
                duration: duration,
                isUncommon: card.vowel.isUncommon,
                hasLengthContrast: card.asksDuration
            )) && isCardInScope(card, duration: duration)
        }
    }

    /// A card that covers both forms is in scope once either form is.
    private func isCardInScope(_ card: VowelCard, duration: VowelCard.VowelDuration) -> Bool {
        let forms: [VowelCard.VowelFormType] = card.coversClosedForm ? [.open, .closed] : [card.form]
        return forms.contains { isSlotInScope(card.vowel, duration: duration, form: $0) }
    }

    private func isSlotInScope(_ vowel: Vowel, duration: VowelCard.VowelDuration, form: VowelCard.VowelFormType) -> Bool {
        let scope = bookScope
        guard scope.isActive, let map = data.bookChapters else { return true }
        return scope.includes(map.placement(of: vowel, duration: duration, form: form))
    }

    /// A card opened from Reference outside the deck: present a shared form's
    /// in-scope slot when it has one, else the card's own.
    private func presentedInBookScope(_ item: FlashcardItem) -> FlashcardItem {
        guard case .vowel(let card) = item,
              let slot = vowelSlot(for: card, checkingFilters: false) else { return item }
        return .vowel(card.presenting(slot))
    }

    private func filterCardsBySettings() -> [FlashcardItem] {
        var cards: [FlashcardItem] = []

        // Add filtered consonants
        for consonant in data.consonants {
            if settings.isConsonantEnabled(consonant) {
                cards.append(.consonant(consonant, includesName: settings.consonantNames))
            }
        }

        // Add filtered vowels
        for card in data.vowelCards {
            if let slot = vowelSlot(for: card, checkingFilters: true) {
                cards.append(.vowel(card.presenting(slot)))
            }
        }

        // Add filtered tone rules
        for card in data.toneRuleCards {
            if isToneRuleCardEnabled(card) {
                cards.append(.toneRule(card))
            }
        }

        // Add tone marks
        if settings.areToneMarksEnabled {
            for card in data.toneMarkCards {
                cards.append(.toneMark(card))
            }
        }

        // Add filtered clusters
        for cluster in data.clusters {
            if settings.isClusterEnabled(cluster) {
                cards.append(.cluster(cluster))
            }
        }

        return cards
    }

    /// Returns all cards (unfiltered)
    var allCards: [FlashcardItem] {
        var cards: [FlashcardItem] = []

        for consonant in data.consonants {
            cards.append(.consonant(consonant, includesName: settings.consonantNames))
        }

        for card in data.vowelCards {
            cards.append(.vowel(card))
        }

        for card in data.toneRuleCards {
            cards.append(.toneRule(card))
        }

        for card in data.toneMarkCards {
            cards.append(.toneMark(card))
        }

        for cluster in data.clusters {
            cards.append(.cluster(cluster))
        }

        return cards
    }

    /// Whether current filters exclude some cards
    var hasActiveFilters: Bool {
        filteredCards.count < allCards.count
    }

    private func isToneRuleCardEnabled(_ card: ToneRuleCard) -> Bool {
        settings.isToneRuleEnabled(initialConsonant: card.rule.initialConsonant)
    }

    // MARK: - Current Card

    var currentCard: FlashcardItem? {
        // Return override card if set (from Reference navigation)
        if let override = overrideCard {
            return override
        }
        return activeStrategy.currentCard
    }

    /// Current index (for sequential mode display)
    var currentIndex: Int {
        if let id = currentCard?.id {
            return sequentialStrategy.indexOf(cardId: id) ?? 0
        }
        return 0
    }

    // MARK: - Shuffled Rounds

    /// Position in the Shuffled pass or retry round; nil in other modes, on the
    /// summary, and while a card opened from Reference is showing.
    var roundPosition: ShuffledStrategy.Position? {
        guard isShuffled, overrideCard == nil else { return nil }
        return shuffledStrategy.position
    }

    /// The Shuffled round summary; nil in other modes, during a round, and while
    /// a card opened from Reference takes its place.
    var roundSummary: ShuffledStrategy.Summary? {
        guard isShuffled, overrideCard == nil else { return nil }
        return shuffledStrategy.summary
    }

    func startRetry() {
        shuffledStrategy.startRetry()
        attempt += 1
    }

    func startSkipped() {
        shuffledStrategy.startSkipped()
        attempt += 1
    }

    func startPracticeMissed() {
        shuffledStrategy.startPracticeMissed()
        attempt += 1
    }

    func startNewRound() {
        shuffledStrategy.startNewRound()
        attempt += 1
    }

    // MARK: - Answers

    /// Records an answer to `card` when the mode grades it, and returns the SRS
    /// outcome, or nil for a practice-only answer (a Shuffled retry, or a repeat
    /// answer in a Shuffled pass). A card opened from Reference always records.
    @discardableResult
    func recordAnswer(for card: FlashcardItem, correct: Bool) -> ReviewOutcome? {
        if isShuffled, overrideCard == nil,
           !shuffledStrategy.noteAnswer(cardId: card.id, correct: correct) {
            return nil
        }
        return learningModel.recordResult(for: card, correct: correct, fullTesting: !isPartialTesting(card))
    }

    // MARK: - Navigation

    func nextCard() {
        navigate { activeStrategy.nextCard() }
    }

    func previousCard() {
        navigate { activeStrategy.previousCard() }
    }

    /// Clears a card opened from Reference and resumes normal navigation. In
    /// Shuffled, the swipe is spent closing it: the round card or summary comes
    /// back unchanged.
    private func navigate(_ move: () -> Void) {
        let closesShuffledOverride = isShuffled && overrideCard != nil
        overrideCard = nil
        if !closesShuffledOverride {
            move()
        }
        attempt += 1
    }

    /// The selection mode changed (here or via iCloud). Every mode change is a
    /// new quiz attempt, so a same-type card never inherits the previous card's
    /// answer state, and Shuffled always starts a fresh pass.
    func applySelectionModeChange() {
        updateStrategies()
        shuffledStrategy.startNewRound()
        attempt += 1
    }

    /// Practice a catalog card once and keep deck navigation on its normal copy.
    private func jumpOrOverride(to item: FlashcardItem, preferredDuration: VowelCard.VowelDuration? = nil) {
        // Look the card up in a deck that matches the settings the card was built with.
        syncDeck()
        let card: FlashcardItem
        if let index = sequentialStrategy.indexOf(cardId: item.id) {
            card = filteredCards.first { $0.id == item.id } ?? item
            if isShuffled {
                // A one-off that leaves the Shuffled round where it was
                overrideCard = card
            } else {
                sequentialStrategy.jumpTo(index: index)
                wanikaniStrategy.jumpTo(card: card)
                overrideCard = nil
            }
        } else {
            card = presentedInBookScope(item)
            overrideCard = card
        }

        // Explicit Practice can use the selected reading for this attempt.
        // Prefer an in-chapter example when search surfaced a later reading.
        if case .vowel(let vowel) = card, vowel.acceptsBothDurations,
           let preferredDuration, preferredDuration != vowel.shownDuration,
           isCardInScope(vowel, duration: preferredDuration) {
            overrideCard = .vowel(vowel.presenting(preferredDuration))
        }
        attempt += 1
    }

    func practice(_ item: ReferenceItem) {
        switch item {
        case .consonant(let id): jumpToConsonant(id)
        case .vowel(let id, let variant, let text):
            guard let card = data.vowelCards.first(where: { $0.vowel.id == id && $0.covers(form: text) }) else { return }
            jumpOrOverride(to: .vowel(card), preferredDuration: variant.duration)
        case .toneMark(_, let soundKey): jumpToToneMark(soundKey)
        case .toneRule(let id): jumpToToneRule(id)
        case .cluster(let id): jumpToCluster(id)
        }
    }

    /// Jump to a consonant by character
    func jumpToConsonant(_ character: String) {
        guard let consonant = data.consonants.first(where: { $0.character == character }) else { return }
        jumpOrOverride(to: .consonant(consonant, includesName: settings.consonantNames))
    }

    /// Jump to a tone mark by display string
    func jumpToToneMark(_ display: String) {
        guard let toneMarkCard = data.toneMarkCards.first(where: { $0.display == display }) else { return }
        jumpOrOverride(to: .toneMark(toneMarkCard))
    }

    /// Jump to a tone rule by ID
    func jumpToToneRule(_ ruleId: String) {
        guard let ruleCard = data.toneRuleCards.first(where: { $0.rule.id == ruleId }) else { return }
        jumpOrOverride(to: .toneRule(ruleCard))
    }

    /// Jump to a cluster by ID
    func jumpToCluster(_ clusterId: String) {
        guard let cluster = data.clusters.first(where: { $0.id == clusterId }) else { return }
        jumpOrOverride(to: .cluster(cluster))
    }

    // MARK: - Deck Synchronization

    /// Apply the current deck settings once. When they differ from the
    /// applied deck: rebuild it, carry a card opened from Reference across
    /// the change, and restart selection (one new attempt). Otherwise do
    /// nothing. Call after every settings change, including an iCloud reload;
    /// `ContentView` observes `deckSettings` and calls this.
    ///
    /// Opened-card rules:
    /// - Consonant-name mode changed: a consonant is rebuilt in the new mode,
    ///   so it keeps showing but records progress under the new mode's ID.
    /// - Chapter scope changed: the card stays only if the new deck includes
    ///   it, and then as the deck's copy so it picks up the new presentation.
    /// - Other filters: the card stays as it is.
    @discardableResult
    func syncDeck() -> Bool {
        let next = settings.deckSettings
        guard next != appliedSettings else { return false }
        let previous = appliedSettings
        appliedSettings = next
        filteredCards = buildDeck()

        if next.consonantNames != previous.consonantNames,
           case .consonant(let consonant, _) = overrideCard {
            overrideCard = .consonant(consonant, includesName: next.consonantNames)
        }
        if next.changesBookScope(from: previous), let override = overrideCard {
            overrideCard = filteredCards.first { $0.id == override.id }
        }
        restart()
        return true
    }

    /// Settings and progress arrived from iCloud: reload both, then apply the
    /// deck, so Smart selection picks from the reloaded progress.
    func reloadFromSyncedStore() {
        settings.reload()
        learningModel.reload()
        syncDeck()
    }

    private func restart() {
        updateStrategies()
        sequentialStrategy.reset()
        wanikaniStrategy.reset()
        shuffledStrategy.reset()
        attempt += 1
    }
}

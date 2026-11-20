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

    // Override card (shown once when jumping from Reference, clears on navigation)
    private var overrideCard: FlashcardItem? = nil

    /// Current active strategy based on settings
    private var activeStrategy: CardSelectionStrategy {
        settings.useIntelligentSelection ? wanikaniStrategy : sequentialStrategy
    }

    var isLoaded: Bool {
        data.isLoaded
    }

    init(settings: FlashcardSettings, learningModel: LearningModel, data: ThaiDataStore) {
        self.settings = settings
        self.learningModel = learningModel
        self.data = data
        self.vowelPlacementsByForm = Self.makeVowelPlacementsByForm(data)
        updateStrategies()
    }

    // MARK: - Book Chapter Scope

    /// The chapter scope from settings; Off when the mapping failed to load.
    var bookScope: BookScope {
        BookScope(settings: settings, map: data.bookChapters)
    }

    /// Chapter placements of every Reference slot, by written form. A vowel card
    /// stands for each slot sharing its form (เกิ- is both the short and the
    /// long closed slot), so it is eligible once any of those slots is.
    private let vowelPlacementsByForm: [String: [BookPlacement?]]

    private static func makeVowelPlacementsByForm(_ data: ThaiDataStore) -> [String: [BookPlacement?]] {
        guard let map = data.bookChapters else { return [:] }
        var result: [String: [BookPlacement?]] = [:]
        for vowel in data.vowels {
            let slots: [(String?, VowelCard.VowelDuration, VowelCard.VowelFormType)] = [
                (vowel.short.closed, .short, .closed), (vowel.short.open, .short, .open),
                (vowel.long.closed, .long, .closed), (vowel.long.open, .long, .open),
            ]
            for case let (form?, duration, formType) in slots {
                result[form, default: []].append(map.placement(of: vowel, duration: duration, form: formType))
            }
        }
        return result
    }

    /// Whether the book has introduced this card's content by the chosen chapter.
    func isInBookScope(_ item: FlashcardItem) -> Bool {
        let scope = bookScope
        guard scope.isActive, let map = data.bookChapters else { return true }
        switch item {
        case .consonant(let consonant, _):
            return scope.includes(map.placement(of: consonant))
        case .vowel(let card):
            let placements = vowelPlacementsByForm[card.display] ?? [nil]
            return placements.contains { scope.includes($0) }
        case .toneMark(let card):
            return scope.includes(map.placement(of: card))
        case .toneRule(let card):
            return scope.includes(map.placement(of: card.rule, sample: card.sample))
        case .cluster(let cluster):
            return scope.includes(map.placement(of: cluster))
        }
    }

    /// SRS cap for a card, judged against the eligible deck (`QuestionCap`).
    /// The lock icon and grading both use this.
    func isPartialTesting(_ card: FlashcardItem) -> Bool {
        QuestionCap.isCapped(card, deck: filteredCards)
    }

    /// Update both strategies with current filtered cards
    private func updateStrategies() {
        let cards = filteredCards
        sequentialStrategy.update(cards: cards, learningModel: learningModel)
        wanikaniStrategy.update(cards: cards, learningModel: learningModel)
    }

    // MARK: - Filtered Cards

    /// Returns all cards that match current settings and the chapter scope, in order
    var filteredCards: [FlashcardItem] {
        filterCardsBySettings().filter(isInBookScope).map(presentedInBookScope)
    }

    /// A shared-form vowel card (เกิ-) is built from its short slot. When only
    /// its long slot is in scope, present that slot's example instead; the
    /// progress id and both accepted durations are unchanged.
    private func presentedInBookScope(_ item: FlashcardItem) -> FlashcardItem {
        guard case .vowel(let card) = item, card.acceptsBothDurations,
              bookScope.isActive, let map = data.bookChapters else { return item }
        let ownSlotInScope = bookScope.includes(map.placement(of: card.vowel, duration: card.duration, form: card.form))
        guard !ownSlotInScope else { return item }
        let other: VowelCard.VowelDuration = card.duration == .short ? .long : .short
        guard bookScope.includes(map.placement(of: card.vowel, duration: other, form: card.form)) else { return item }
        return .vowel(card.presenting(other))
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
            if isVowelCardEnabled(card) {
                cards.append(.vowel(card))
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

    private func isVowelCardEnabled(_ card: VowelCard) -> Bool {
        settings.isVowelCardEnabled(
            duration: card.duration,
            isUncommon: card.vowel.isUncommon,
            hasLengthContrast: card.asksDuration
        )
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

    // MARK: - Navigation

    func nextCard() {
        // Clear override and resume normal navigation
        overrideCard = nil
        activeStrategy.nextCard()
    }

    func previousCard() {
        // Clear override and resume normal navigation
        overrideCard = nil
        activeStrategy.previousCard()
    }

    /// Jump to a specific card (e.g., from Reference view)
    func jumpTo(item: FlashcardItem) {
        // Use the deck's copy: it carries the chapter scope's presentation
        // (a shared vowel form showing its in-scope slot), which a card
        // fetched from the catalog does not.
        let item = filteredCards.first { $0.id == item.id } ?? item
        // Jump in both strategies to keep them in sync
        if let index = sequentialStrategy.indexOf(cardId: item.id) {
            sequentialStrategy.jumpTo(index: index)
        }
        wanikaniStrategy.jumpTo(card: item)
    }

    /// Jump to a card, using override if not in the filtered list
    private func jumpOrOverride(to item: FlashcardItem) {
        if sequentialStrategy.indexOf(cardId: item.id) != nil {
            overrideCard = nil
            jumpTo(item: item)
        } else {
            // Not in the deck (outside the chapter, or excluded by Filters). Still
            // present a shared vowel form's in-scope slot when it has one.
            overrideCard = presentedInBookScope(item)
        }
    }

    /// Jump to a consonant by character
    func jumpToConsonant(_ character: String) {
        guard let consonant = data.consonants.first(where: { $0.character == character }) else { return }
        jumpOrOverride(to: .consonant(consonant, includesName: settings.consonantNames))
    }

    /// Jump to a vowel by display string
    func jumpToVowel(_ display: String) {
        guard let vowelCard = data.vowelCards.first(where: { $0.display == display }) else { return }
        jumpOrOverride(to: .vowel(vowelCard))
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

    /// Switch consonant cards to the current `consonantNames` mode. A consonant
    /// opened from Reference is rebuilt in the new mode so it keeps showing but
    /// records progress under the new mode's ID; then the session restarts.
    func applyConsonantMode() {
        if case .consonant(let consonant, _) = overrideCard {
            overrideCard = .consonant(consonant, includesName: settings.consonantNames)
        }
        resetToStart()
    }

    /// The chapter scope changed (here, from the other tab, or via iCloud):
    /// restart the deck, and drop a card opened from Reference that the new
    /// scope or filters no longer include.
    func applyBookScopeChange() {
        // Keep an opened card only if the deck now includes it, and then as the
        // deck's copy so it picks up the new scope's presentation.
        if let override = overrideCard {
            overrideCard = filteredCards.first { $0.id == override.id }
        }
        resetToStart()
    }

    /// Reset to first card and update strategies (call when settings change)
    func resetToStart() {
        updateStrategies()
        sequentialStrategy.reset()
        wanikaniStrategy.reset()
    }
}

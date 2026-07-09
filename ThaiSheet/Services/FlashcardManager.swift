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
        updateStrategies()
    }

    /// Update both strategies with current filtered cards
    private func updateStrategies() {
        let cards = filteredCards
        sequentialStrategy.update(cards: cards, learningModel: learningModel)
        wanikaniStrategy.update(cards: cards, learningModel: learningModel)
    }

    // MARK: - Filtered Cards

    /// Returns all cards that match current settings, in order
    var filteredCards: [FlashcardItem] {
        var cards: [FlashcardItem] = []

        // Add filtered consonants
        for consonant in data.consonants {
            if settings.isConsonantEnabled(consonant) {
                cards.append(.consonant(consonant))
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
            cards.append(.consonant(consonant))
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
        settings.isVowelCardEnabled(duration: card.duration, isUncommon: card.vowel.isUncommon)
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
            overrideCard = item
        }
    }

    /// Jump to a consonant by character
    func jumpToConsonant(_ character: String) {
        guard let consonant = data.consonants.first(where: { $0.character == character }) else { return }
        jumpOrOverride(to: .consonant(consonant))
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

    /// Reset to first card and update strategies (call when settings change)
    func resetToStart() {
        updateStrategies()
        sequentialStrategy.reset()
        wanikaniStrategy.reset()
    }
}

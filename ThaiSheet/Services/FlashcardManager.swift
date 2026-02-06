//
//  FlashcardManager.swift
//  ThaiSheet
//

import Foundation
import SwiftUI

@Observable
class FlashcardManager {
    // Raw data (all cards, unfiltered)
    private var allConsonants: [Consonant] = []
    private var allVowels: [Vowel] = []
    private var allVowelCards: [VowelCard] = []
    private var allToneMarks: [ToneMark] = []
    private var allToneMarkCards: [ToneMarkCard] = []
    private var allToneRules: [ToneRule] = []
    private var allToneRuleCards: [ToneRuleCard] = []
    private var allClusters: [Cluster] = []

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
        !allConsonants.isEmpty && !allVowelCards.isEmpty &&
        !allToneMarkCards.isEmpty && !allToneRuleCards.isEmpty && !allClusters.isEmpty
    }

    init(settings: FlashcardSettings, learningModel: LearningModel) {
        self.settings = settings
        self.learningModel = learningModel
        loadAllData()
    }

    // MARK: - Data Loading

    func loadAllData() {
        allConsonants = Consonant.loadAll()
        allVowels = Vowel.loadAll()
        allVowelCards = VowelCard.allCards(from: allVowels)
        allToneMarks = ToneMark.loadAll()
        allToneMarkCards = ToneMarkCard.allCards(from: allToneMarks)
        allToneRules = ToneRule.loadAll()
        allToneRuleCards = ToneRuleCard.allCards(from: allToneRules)
        allClusters = Cluster.loadAll()

        // Update strategies with initial cards
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
        for consonant in allConsonants {
            if settings.isConsonantEnabled(consonant) {
                cards.append(.consonant(consonant))
            }
        }

        // Add filtered vowels
        for card in allVowelCards {
            if isVowelCardEnabled(card) {
                cards.append(.vowel(card))
            }
        }

        // Add filtered tone rules
        for card in allToneRuleCards {
            if isToneRuleCardEnabled(card) {
                cards.append(.toneRule(card))
            }
        }

        // Add tone marks
        if settings.areToneMarksEnabled {
            for card in allToneMarkCards {
                cards.append(.toneMark(card))
            }
        }

        // Add filtered clusters
        for cluster in allClusters {
            if settings.isClusterEnabled(cluster) {
                cards.append(.cluster(cluster))
            }
        }

        return cards
    }

    /// Returns all cards (unfiltered)
    var allCards: [FlashcardItem] {
        var cards: [FlashcardItem] = []

        for consonant in allConsonants {
            cards.append(.consonant(consonant))
        }

        for card in allVowelCards {
            cards.append(.vowel(card))
        }

        for card in allToneRuleCards {
            cards.append(.toneRule(card))
        }

        for card in allToneMarkCards {
            cards.append(.toneMark(card))
        }

        for cluster in allClusters {
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
        guard let consonant = allConsonants.first(where: { $0.character == character }) else { return }
        jumpOrOverride(to: .consonant(consonant))
    }

    /// Jump to a vowel by display string
    func jumpToVowel(_ display: String) {
        guard let vowelCard = allVowelCards.first(where: { $0.display == display }) else { return }
        jumpOrOverride(to: .vowel(vowelCard))
    }

    /// Jump to a tone mark by display string
    func jumpToToneMark(_ display: String) {
        guard let toneMarkCard = allToneMarkCards.first(where: { $0.display == display }) else { return }
        jumpOrOverride(to: .toneMark(toneMarkCard))
    }

    /// Jump to a tone rule by ID
    func jumpToToneRule(_ ruleId: String) {
        guard let ruleCard = allToneRuleCards.first(where: { $0.rule.id == ruleId }) else { return }
        jumpOrOverride(to: .toneRule(ruleCard))
    }

    /// Jump to a cluster by ID
    func jumpToCluster(_ clusterId: String) {
        guard let cluster = allClusters.first(where: { $0.id == clusterId }) else { return }
        jumpOrOverride(to: .cluster(cluster))
    }

    /// Reset to first card and update strategies (call when settings change)
    func resetToStart() {
        updateStrategies()
        sequentialStrategy.reset()
        wanikaniStrategy.reset()
    }

    // MARK: - For generating quiz options

    var allConsonantsForOptions: [Consonant] {
        allConsonants
    }

    var allVowelsForOptions: [Vowel] {
        allVowels
    }

    var allClustersForOptions: [Cluster] {
        allClusters
    }
}

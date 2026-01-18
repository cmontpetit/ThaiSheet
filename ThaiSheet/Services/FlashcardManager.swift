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

    // Track settings state to detect changes
    private var lastSettingsHash: Int = 0

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
        allToneMarkCards = ToneMarkCard.allCards(from: allToneMarks, consonants: allConsonants)
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

        // Add tone marks (all or none)
        if settings.toneMarks {
            for card in allToneMarkCards {
                cards.append(.toneMark(card))
            }
        }

        // Add clusters (all or none)
        if settings.clusters {
            for cluster in allClusters {
                cards.append(.cluster(cluster))
            }
        }

        return cards
    }

    private func isVowelCardEnabled(_ card: VowelCard) -> Bool {
        switch card.duration {
        case .long: return settings.longVowels
        case .short: return settings.shortVowels
        }
    }

    private func isToneRuleCardEnabled(_ card: ToneRuleCard) -> Bool {
        switch card.rule.initialConsonant {
        case "High": return settings.highToneRules
        case "Mid": return settings.midToneRules
        case "Low": return settings.lowToneRules
        default: return false
        }
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

    /// Jump to a consonant by character (sets override if not in filtered list)
    func jumpToConsonant(_ character: String) {
        guard let consonant = allConsonants.first(where: { $0.character == character }) else { return }
        let item = FlashcardItem.consonant(consonant)

        if sequentialStrategy.indexOf(cardId: item.id) != nil {
            // Card is in filtered list, jump to it
            overrideCard = nil
            jumpTo(item: item)
        } else {
            // Card not in filtered list, show as override
            overrideCard = item
        }
    }

    /// Jump to a vowel by display string (sets override if not in filtered list)
    func jumpToVowel(_ display: String) {
        guard let vowelCard = allVowelCards.first(where: { $0.display == display }) else { return }
        let item = FlashcardItem.vowel(vowelCard)

        if sequentialStrategy.indexOf(cardId: item.id) != nil {
            // Card is in filtered list, jump to it
            overrideCard = nil
            jumpTo(item: item)
        } else {
            // Card not in filtered list, show as override
            overrideCard = item
        }
    }

    /// Jump to a tone mark by display string (sets override if not in filtered list)
    func jumpToToneMark(_ display: String) {
        guard let toneMarkCard = allToneMarkCards.first(where: { $0.display == display }) else { return }
        let item = FlashcardItem.toneMark(toneMarkCard)

        if sequentialStrategy.indexOf(cardId: item.id) != nil {
            // Card is in filtered list, jump to it
            overrideCard = nil
            jumpTo(item: item)
        } else {
            // Card not in filtered list, show as override
            overrideCard = item
        }
    }

    /// Jump to a tone rule by ID (sets override if not in filtered list)
    func jumpToToneRule(_ ruleId: String) {
        guard let ruleCard = allToneRuleCards.first(where: { $0.rule.id == ruleId }) else { return }
        let item = FlashcardItem.toneRule(ruleCard)

        if sequentialStrategy.indexOf(cardId: item.id) != nil {
            // Card is in filtered list, jump to it
            overrideCard = nil
            jumpTo(item: item)
        } else {
            // Card not in filtered list, show as override
            overrideCard = item
        }
    }

    /// Reset to first card and update strategies (call when settings change)
    func resetToStart() {
        updateStrategies()
        sequentialStrategy.reset()
        wanikaniStrategy.reset()
    }

    /// Jump to a cluster by ID (sets override if not in filtered list)
    func jumpToCluster(_ clusterId: String) {
        guard let cluster = allClusters.first(where: { $0.id == clusterId }) else { return }
        let item = FlashcardItem.cluster(cluster)

        if sequentialStrategy.indexOf(cardId: item.id) != nil {
            // Card is in filtered list, jump to it
            overrideCard = nil
            jumpTo(item: item)
        } else {
            // Card not in filtered list, show as override
            overrideCard = item
        }
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

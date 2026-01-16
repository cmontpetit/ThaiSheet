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

    // Settings reference
    let settings: FlashcardSettings

    // Current position in filtered cards
    private(set) var currentIndex: Int = 0

    // Override card (shown once when jumping from Reference, clears on navigation)
    private var overrideCard: FlashcardItem? = nil

    // Track settings state to detect changes
    private var lastSettingsHash: Int = 0

    var isLoaded: Bool {
        !allConsonants.isEmpty && !allVowelCards.isEmpty &&
        !allToneMarkCards.isEmpty && !allToneRuleCards.isEmpty
    }

    init(settings: FlashcardSettings) {
        self.settings = settings
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

        let cards = filteredCards
        guard !cards.isEmpty else { return nil }

        // Ensure index is valid
        let safeIndex = currentIndex % cards.count
        return cards[safeIndex]
    }

    // MARK: - Navigation

    func nextCard() {
        // Clear override and resume normal navigation
        overrideCard = nil

        let cards = filteredCards
        guard !cards.isEmpty else { return }

        currentIndex = (currentIndex + 1) % cards.count
    }

    func previousCard() {
        // Clear override and resume normal navigation
        overrideCard = nil

        let cards = filteredCards
        guard !cards.isEmpty else { return }

        currentIndex = (currentIndex - 1 + cards.count) % cards.count
    }

    /// Jump to a specific card (e.g., from Reference view)
    func jumpTo(item: FlashcardItem) {
        let cards = filteredCards
        if let index = cards.firstIndex(where: { $0.id == item.id }) {
            currentIndex = index
        }
    }

    /// Jump to a consonant by character (sets override if not in filtered list)
    func jumpToConsonant(_ character: String) {
        guard let consonant = allConsonants.first(where: { $0.character == character }) else { return }

        let cards = filteredCards
        if let index = cards.firstIndex(where: {
            if case .consonant(let c) = $0 {
                return c.character == character
            }
            return false
        }) {
            // Card is in filtered list, jump to it
            overrideCard = nil
            currentIndex = index
        } else {
            // Card not in filtered list, show as override
            overrideCard = .consonant(consonant)
        }
    }

    /// Jump to a vowel by display string (sets override if not in filtered list)
    func jumpToVowel(_ display: String) {
        guard let vowelCard = allVowelCards.first(where: { $0.display == display }) else { return }

        let cards = filteredCards
        if let index = cards.firstIndex(where: {
            if case .vowel(let v) = $0 {
                return v.display == display
            }
            return false
        }) {
            // Card is in filtered list, jump to it
            overrideCard = nil
            currentIndex = index
        } else {
            // Card not in filtered list, show as override
            overrideCard = .vowel(vowelCard)
        }
    }

    /// Jump to a tone mark by display string (sets override if not in filtered list)
    func jumpToToneMark(_ display: String) {
        guard let toneMarkCard = allToneMarkCards.first(where: { $0.display == display }) else { return }

        let cards = filteredCards
        if let index = cards.firstIndex(where: {
            if case .toneMark(let t) = $0 {
                return t.display == display
            }
            return false
        }) {
            // Card is in filtered list, jump to it
            overrideCard = nil
            currentIndex = index
        } else {
            // Card not in filtered list, show as override
            overrideCard = .toneMark(toneMarkCard)
        }
    }

    /// Jump to a tone rule by ID (sets override if not in filtered list)
    func jumpToToneRule(_ ruleId: String) {
        guard let ruleCard = allToneRuleCards.first(where: { $0.rule.id == ruleId }) else { return }

        let cards = filteredCards
        if let index = cards.firstIndex(where: {
            if case .toneRule(let t) = $0 {
                return t.rule.id == ruleId
            }
            return false
        }) {
            // Card is in filtered list, jump to it
            overrideCard = nil
            currentIndex = index
        } else {
            // Card not in filtered list, show as override
            overrideCard = .toneRule(ruleCard)
        }
    }

    /// Reset to first card (call when settings change)
    func resetToStart() {
        currentIndex = 0
    }

    // MARK: - For generating quiz options

    var allConsonantsForOptions: [Consonant] {
        allConsonants
    }

    var allVowelsForOptions: [Vowel] {
        allVowels
    }
}

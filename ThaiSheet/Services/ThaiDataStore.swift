//
//  ThaiDataStore.swift
//  ThaiSheet
//

import SwiftUI

/// All bundled cheatsheet data, loaded once and shared by the Reference
/// browser and the flashcard system via the environment.
final class ThaiDataStore {
    let consonants: [Consonant]
    let vowels: [Vowel]
    let vowelCards: [VowelCard]
    let toneMarks: [ToneMark]
    let toneMarkCards: [ToneMarkCard]
    let toneRules: [ToneRule]
    let toneRuleCards: [ToneRuleCard]
    let clusters: [Cluster]

    init() {
        consonants = Consonant.loadAll()
        vowels = Vowel.loadAll()
        vowelCards = VowelCard.allCards(from: vowels)
        toneMarks = ToneMark.loadAll()
        toneMarkCards = ToneMarkCard.allCards(from: toneMarks)
        toneRules = ToneRule.loadAll()
        toneRuleCards = ToneRuleCard.allCards(from: toneRules)
        clusters = Cluster.loadAll()
    }

    var isLoaded: Bool {
        !consonants.isEmpty && !vowelCards.isEmpty &&
        !toneMarkCards.isEmpty && !toneRuleCards.isEmpty && !clusters.isEmpty
    }
}

// MARK: - Environment Key

private struct ThaiDataStoreKey: EnvironmentKey {
    static let defaultValue = ThaiDataStore()
}

extension EnvironmentValues {
    var thaiData: ThaiDataStore {
        get { self[ThaiDataStoreKey.self] }
        set { self[ThaiDataStoreKey.self] = newValue }
    }
}

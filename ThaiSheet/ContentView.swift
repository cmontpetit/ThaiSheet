//
//  ContentView.swift
//  ThaiSheet
//
//  Created by Claude Montpetit on 2026-01-11.
//

import SwiftUI

enum AppTab: Int {
    case flashcards = 0
    case reference = 1
}

enum FlashcardType {
    case consonant
    case vowel
    case toneMark
    case toneRule
}

struct ContentView: View {
    @State private var settings = FlashcardSettings()
    @State private var selectedTab: AppTab = .flashcards
    @State private var highlightedConsonant: String? = nil
    @State private var highlightedVowel: String? = nil
    @State private var highlightedToneMark: String? = nil
    @State private var highlightedToneRule: String? = nil
    @State private var flashcardStartingConsonant: String? = nil
    @State private var flashcardStartingVowel: String? = nil
    @State private var flashcardStartingToneMark: String? = nil
    @State private var flashcardStartingToneRule: String? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            FlashcardsView(
                settings: settings,
                highlightedConsonant: $highlightedConsonant,
                highlightedVowel: $highlightedVowel,
                highlightedToneMark: $highlightedToneMark,
                highlightedToneRule: $highlightedToneRule,
                startingConsonant: $flashcardStartingConsonant,
                startingVowel: $flashcardStartingVowel,
                startingToneMark: $flashcardStartingToneMark,
                startingToneRule: $flashcardStartingToneRule,
                selectedTab: $selectedTab
            )
            .tabItem {
                Label("Flashcards", systemImage: "rectangle.on.rectangle")
            }
            .tag(AppTab.flashcards)

            CheatsheetBrowserView(
                highlightedConsonant: $highlightedConsonant,
                highlightedVowel: $highlightedVowel,
                highlightedToneMark: $highlightedToneMark,
                highlightedToneRule: $highlightedToneRule,
                flashcardStartingConsonant: $flashcardStartingConsonant,
                flashcardStartingVowel: $flashcardStartingVowel,
                flashcardStartingToneMark: $flashcardStartingToneMark,
                flashcardStartingToneRule: $flashcardStartingToneRule,
                selectedTab: $selectedTab
            )
            .tabItem {
                Label("Reference", systemImage: "book")
            }
            .tag(AppTab.reference)
        }
    }
}

struct FlashcardsView: View {
    var settings: FlashcardSettings
    @Binding var highlightedConsonant: String?
    @Binding var highlightedVowel: String?
    @Binding var highlightedToneMark: String?
    @Binding var highlightedToneRule: String?
    @Binding var startingConsonant: String?
    @Binding var startingVowel: String?
    @Binding var startingToneMark: String?
    @Binding var startingToneRule: String?
    @Binding var selectedTab: AppTab

    @State private var showingSettings = false
    @State private var consonants: [Consonant] = []
    @State private var vowels: [Vowel] = []
    @State private var vowelCards: [VowelCard] = []
    @State private var toneMarks: [ToneMark] = []
    @State private var toneMarkCards: [ToneMarkCard] = []
    @State private var toneRules: [ToneRule] = []
    @State private var toneRuleCards: [ToneRuleCard] = []
    @State private var currentType: FlashcardType = .consonant
    @State private var consonantIndex: Int = 0
    @State private var vowelIndex: Int = 0
    @State private var toneMarkIndex: Int = 0
    @State private var toneRuleIndex: Int = 0

    // MARK: - Filtered Arrays

    private var filteredConsonants: [Consonant] {
        consonants.filter { settings.isConsonantEnabled($0) }
    }

    private var filteredVowelCards: [VowelCard] {
        vowelCards.filter { card in
            switch card.duration {
            case .long: return settings.longVowels
            case .short: return settings.shortVowels
            }
        }
    }

    private var filteredToneMarkCards: [ToneMarkCard] {
        settings.areToneMarksEnabled ? toneMarkCards : []
    }

    private var filteredToneRuleCards: [ToneRuleCard] {
        toneRuleCards.filter { card in
            switch card.rule.initialConsonant {
            case "High": return settings.highToneRules
            case "Mid": return settings.midToneRules
            case "Low": return settings.lowToneRules
            default: return false
            }
        }
    }

    // MARK: - Enabled Types (in order)

    private var enabledTypes: [FlashcardType] {
        var types: [FlashcardType] = []
        if settings.hasAnyConsonantEnabled { types.append(.consonant) }
        if settings.hasAnyVowelEnabled { types.append(.vowel) }
        if settings.hasAnyToneRuleEnabled { types.append(.toneRule) }
        if settings.areToneMarksEnabled { types.append(.toneMark) }
        return types
    }

    private var typeLabel: String {
        switch currentType {
        case .consonant: return "Consonant"
        case .vowel: return "Vowel"
        case .toneMark: return "Tone Mark"
        case .toneRule: return "Tone Rule"
        }
    }

    var body: some View {
        NavigationStack {
            if consonants.isEmpty || vowelCards.isEmpty || toneMarkCards.isEmpty || toneRuleCards.isEmpty {
                ContentUnavailableView(
                    "Loading...",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Loading flashcards")
                )
            } else {
                VStack(spacing: 0) {
                    // Type indicator
                    HStack {
                        Text(typeLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Current flashcard view
                    switch currentType {
                    case .consonant:
                        ConsonantFlashcardView(
                            consonants: filteredConsonants,
                            currentIndex: $consonantIndex,
                            startingConsonant: $startingConsonant,
                            onViewInReference: { character in
                                highlightedConsonant = character
                                selectedTab = .reference
                            },
                            onNextCard: { handleNextCard(for: .consonant) }
                        )
                    case .vowel:
                        VowelFlashcardView(
                            cards: filteredVowelCards,
                            allVowels: vowels,
                            currentIndex: $vowelIndex,
                            startingVowel: $startingVowel,
                            onViewInReference: { vowel in
                                highlightedVowel = vowel
                                selectedTab = .reference
                            },
                            onNextCard: { handleNextCard(for: .vowel) }
                        )
                    case .toneMark:
                        ToneMarkFlashcardView(
                            cards: filteredToneMarkCards,
                            currentIndex: $toneMarkIndex,
                            startingToneMark: $startingToneMark,
                            onViewInReference: { display in
                                highlightedToneMark = display
                                selectedTab = .reference
                            },
                            onNextCard: { handleNextCard(for: .toneMark) }
                        )
                    case .toneRule:
                        ToneRuleFlashcardView(
                            cards: filteredToneRuleCards,
                            currentIndex: $toneRuleIndex,
                            startingRuleId: $startingToneRule,
                            onViewInReference: { ruleId in
                                highlightedToneRule = ruleId
                                selectedTab = .reference
                            },
                            onNextCard: { handleNextCard(for: .toneRule) }
                        )
                    }
                }
                .navigationTitle("Flashcards")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            FlashcardSettingsView(settings: settings)
        }
        .onChange(of: settings.highConsonants) { _, _ in ensureValidType() }
        .onChange(of: settings.midConsonants) { _, _ in ensureValidType() }
        .onChange(of: settings.lowConsonants) { _, _ in ensureValidType() }
        .onChange(of: settings.uncommonConsonants) { _, _ in ensureValidType() }
        .onChange(of: settings.longVowels) { _, _ in ensureValidType() }
        .onChange(of: settings.shortVowels) { _, _ in ensureValidType() }
        .onChange(of: settings.highToneRules) { _, _ in ensureValidType() }
        .onChange(of: settings.midToneRules) { _, _ in ensureValidType() }
        .onChange(of: settings.lowToneRules) { _, _ in ensureValidType() }
        .onChange(of: settings.toneMarks) { _, _ in ensureValidType() }
        .onAppear {
            if consonants.isEmpty {
                consonants = Consonant.loadAll()
            }
            if vowels.isEmpty {
                vowels = Vowel.loadAll()
                vowelCards = VowelCard.allCards(from: vowels)
            }
            if toneMarks.isEmpty {
                toneMarks = ToneMark.loadAll()
                toneMarkCards = ToneMarkCard.allCards(from: toneMarks, consonants: consonants)
            }
            if toneRules.isEmpty {
                toneRules = ToneRule.loadAll()
                toneRuleCards = ToneRuleCard.allCards(from: toneRules)
            }
        }
        .onChange(of: startingConsonant) { _, newValue in
            if newValue != nil {
                currentType = .consonant
            }
        }
        .onChange(of: startingVowel) { _, newValue in
            if newValue != nil {
                currentType = .vowel
            }
        }
        .onChange(of: startingToneMark) { _, newValue in
            if newValue != nil {
                currentType = .toneMark
            }
        }
        .onChange(of: startingToneRule) { _, newValue in
            if newValue != nil {
                currentType = .toneRule
            }
        }
    }

    // MARK: - Navigation Logic

    private func handleNextCard(for type: FlashcardType) {
        let currentCount: Int
        let currentIndex: Int

        switch type {
        case .consonant:
            currentCount = filteredConsonants.count
            currentIndex = consonantIndex
        case .vowel:
            currentCount = filteredVowelCards.count
            currentIndex = vowelIndex
        case .toneMark:
            currentCount = filteredToneMarkCards.count
            currentIndex = toneMarkIndex
        case .toneRule:
            currentCount = filteredToneRuleCards.count
            currentIndex = toneRuleIndex
        }

        // If there are more cards in current type, advance
        if currentIndex < currentCount - 1 {
            switch type {
            case .consonant: consonantIndex += 1
            case .vowel: vowelIndex += 1
            case .toneMark: toneMarkIndex += 1
            case .toneRule: toneRuleIndex += 1
            }
            return
        }

        // Current type exhausted - find next enabled type
        if let nextType = findNextEnabledType(after: type) {
            switchToType(nextType)
            return
        }

        // No more types - wrap to first enabled type
        if let firstType = enabledTypes.first {
            switchToType(firstType)
        }
    }

    private func findNextEnabledType(after type: FlashcardType) -> FlashcardType? {
        guard let currentTypeIndex = enabledTypes.firstIndex(of: type) else {
            return enabledTypes.first
        }

        let nextIndex = currentTypeIndex + 1
        if nextIndex < enabledTypes.count {
            return enabledTypes[nextIndex]
        }

        return nil
    }

    private func switchToType(_ type: FlashcardType) {
        currentType = type
        switch type {
        case .consonant: consonantIndex = 0
        case .vowel: vowelIndex = 0
        case .toneMark: toneMarkIndex = 0
        case .toneRule: toneRuleIndex = 0
        }
    }

    private func ensureValidType() {
        // If current type is no longer enabled, switch to first enabled type
        if !enabledTypes.contains(currentType) {
            if let firstEnabled = enabledTypes.first {
                switchToType(firstEnabled)
            }
        }

        // Also ensure indices are within bounds
        if consonantIndex >= filteredConsonants.count {
            consonantIndex = 0
        }
        if vowelIndex >= filteredVowelCards.count {
            vowelIndex = 0
        }
        if toneMarkIndex >= filteredToneMarkCards.count {
            toneMarkIndex = 0
        }
        if toneRuleIndex >= filteredToneRuleCards.count {
            toneRuleIndex = 0
        }
    }
}

#Preview {
    ContentView()
}

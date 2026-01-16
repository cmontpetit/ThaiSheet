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
    @Binding var highlightedConsonant: String?
    @Binding var highlightedVowel: String?
    @Binding var highlightedToneMark: String?
    @Binding var highlightedToneRule: String?
    @Binding var startingConsonant: String?
    @Binding var startingVowel: String?
    @Binding var startingToneMark: String?
    @Binding var startingToneRule: String?
    @Binding var selectedTab: AppTab

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
                            consonants: consonants,
                            currentIndex: $consonantIndex,
                            startingConsonant: $startingConsonant,
                            onViewInReference: { character in
                                highlightedConsonant = character
                                selectedTab = .reference
                            }
                        )
                    case .vowel:
                        VowelFlashcardView(
                            cards: vowelCards,
                            allVowels: vowels,
                            currentIndex: $vowelIndex,
                            startingVowel: $startingVowel,
                            onViewInReference: { vowel in
                                highlightedVowel = vowel
                                selectedTab = .reference
                            }
                        )
                    case .toneMark:
                        ToneMarkFlashcardView(
                            cards: toneMarkCards,
                            currentIndex: $toneMarkIndex,
                            startingToneMark: $startingToneMark,
                            onViewInReference: { display in
                                highlightedToneMark = display
                                selectedTab = .reference
                            }
                        )
                    case .toneRule:
                        ToneRuleFlashcardView(
                            cards: toneRuleCards,
                            currentIndex: $toneRuleIndex,
                            startingRuleId: $startingToneRule,
                            onViewInReference: { ruleId in
                                highlightedToneRule = ruleId
                                selectedTab = .reference
                            }
                        )
                    }
                }
            }
        }
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
}

#Preview {
    ContentView()
}

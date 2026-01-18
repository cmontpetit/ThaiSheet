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
    @State private var learningModel = LearningModel()
    @State private var manager: FlashcardManager?
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
            if let manager = manager {
                FlashcardsView(
                    manager: manager,
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
            } else {
                ContentUnavailableView(
                    "Loading...",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Loading flashcards")
                )
                .tabItem {
                    Label("Flashcards", systemImage: "rectangle.on.rectangle")
                }
                .tag(AppTab.flashcards)
            }

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
            .environment(\.learningModel, learningModel)
            .tabItem {
                Label("Reference", systemImage: "book")
            }
            .tag(AppTab.reference)
        }
        .onAppear {
            if manager == nil {
                manager = FlashcardManager(settings: settings, learningModel: learningModel)
            }
        }
    }
}

struct FlashcardsView: View {
    var manager: FlashcardManager
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
    @State private var showingStats = false
    @State private var showingFilter = false
    @State private var filterRefreshID = UUID()

    private var typeLabel: String {
        guard let card = manager.currentCard else { return "Flashcard" }
        switch card.type {
        case .consonant: return "Consonant"
        case .vowel: return "Vowel"
        case .toneMark: return "Tone Mark"
        case .toneRule: return "Tone Rule"
        }
    }

    @ViewBuilder
    private func stageIndicator(for card: FlashcardItem) -> some View {
        let stage = manager.learningModel.srsStage(for: card)
        let isCapped = manager.settings.isPartialTesting(for: card.type)
        StageIndicatorView(mode: .stage(stage: stage, isCapped: isCapped))
    }

    /// Position indicator for sequential mode (e.g., "12 / 44")
    @ViewBuilder
    private var positionIndicator: some View {
        if !manager.settings.useIntelligentSelection {
            let current = manager.currentIndex + 1
            let total = manager.filteredCards.count
            Text("\(current) / \(total)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var body: some View {
        NavigationStack {
            if !manager.isLoaded {
                ContentUnavailableView(
                    "Loading...",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Loading flashcards")
                )
            } else if manager.filteredCards.isEmpty {
                ContentUnavailableView(
                    "No Cards",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Enable some options in settings")
                )
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
            } else if let card = manager.currentCard {
                VStack(spacing: 0) {
                    // Type indicator, position (sequential mode), and stage indicator
                    HStack {
                        Text(typeLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        positionIndicator
                        Spacer()
                        stageIndicator(for: card)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Current flashcard view based on card type
                    switch card {
                    case .consonant(let consonant):
                        ConsonantFlashcardView(
                            consonant: consonant,
                            allConsonants: manager.allConsonantsForOptions,
                            onViewInReference: { character in
                                highlightedConsonant = character
                                selectedTab = .reference
                            },
                            onComplete: { correct in
                                let fullTesting = !manager.settings.isPartialTesting(for: .consonant)
                                manager.learningModel.recordResult(for: card, correct: correct, fullTesting: fullTesting)
                            },
                            onNext: { manager.nextCard() },
                            onPrevious: { manager.previousCard() }
                        )
                    case .vowel(let vowelCard):
                        VowelFlashcardView(
                            card: vowelCard,
                            allVowels: manager.allVowelsForOptions,
                            onViewInReference: { vowel in
                                highlightedVowel = vowel
                                selectedTab = .reference
                            },
                            onComplete: { correct in
                                let fullTesting = !manager.settings.isPartialTesting(for: .vowel)
                                manager.learningModel.recordResult(for: card, correct: correct, fullTesting: fullTesting)
                            },
                            onNext: { manager.nextCard() },
                            onPrevious: { manager.previousCard() }
                        )
                    case .toneMark(let toneMarkCard):
                        ToneMarkFlashcardView(
                            card: toneMarkCard,
                            onViewInReference: { display in
                                highlightedToneMark = display
                                selectedTab = .reference
                            },
                            onComplete: { correct in
                                let fullTesting = !manager.settings.isPartialTesting(for: .toneMark)
                                manager.learningModel.recordResult(for: card, correct: correct, fullTesting: fullTesting)
                            },
                            onNext: { manager.nextCard() },
                            onPrevious: { manager.previousCard() }
                        )
                    case .toneRule(let toneRuleCard):
                        ToneRuleFlashcardView(
                            card: toneRuleCard,
                            onViewInReference: { ruleId in
                                highlightedToneRule = ruleId
                                selectedTab = .reference
                            },
                            onComplete: { correct in
                                let fullTesting = !manager.settings.isPartialTesting(for: .toneRule)
                                manager.learningModel.recordResult(for: card, correct: correct, fullTesting: fullTesting)
                            },
                            onNext: { manager.nextCard() },
                            onPrevious: { manager.previousCard() }
                        )
                    }
                }
                .navigationTitle("Flashcards")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 16) {
                            Button {
                                showingStats = true
                            } label: {
                                Image(systemName: "chart.bar")
                            }
                            Button {
                                showingFilter = true
                            } label: {
                                Image(systemName: manager.settings.isAllSelected
                                    ? "line.3.horizontal.decrease.circle"
                                    : "line.3.horizontal.decrease.circle.fill")
                            }
                            .id(filterRefreshID)
                            Button {
                                showingSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilter) {
            FlashcardFilterView(settings: manager.settings)
        }
        .onChange(of: showingFilter) { _, isShowing in
            if !isShowing {
                // Refresh filter icon when sheet closes
                filterRefreshID = UUID()
            }
        }
        .sheet(isPresented: $showingSettings) {
            FlashcardSettingsView(settings: manager.settings)
        }
        .sheet(isPresented: $showingStats) {
            SRSStatsView(
                learningModel: manager.learningModel,
                filteredCards: manager.filteredCards
            )
        }
        .onChange(of: manager.settings.highConsonants) { _, _ in manager.resetToStart() }
        .onChange(of: manager.settings.midConsonants) { _, _ in manager.resetToStart() }
        .onChange(of: manager.settings.lowConsonants) { _, _ in manager.resetToStart() }
        .onChange(of: manager.settings.uncommonConsonants) { _, _ in manager.resetToStart() }
        .onChange(of: manager.settings.longVowels) { _, _ in manager.resetToStart() }
        .onChange(of: manager.settings.shortVowels) { _, _ in manager.resetToStart() }
        .onChange(of: manager.settings.highToneRules) { _, _ in manager.resetToStart() }
        .onChange(of: manager.settings.midToneRules) { _, _ in manager.resetToStart() }
        .onChange(of: manager.settings.lowToneRules) { _, _ in manager.resetToStart() }
        .onChange(of: manager.settings.toneMarks) { _, _ in manager.resetToStart() }
        .onChange(of: startingConsonant) { _, newValue in
            if let character = newValue {
                manager.jumpToConsonant(character)
                startingConsonant = nil
            }
        }
        .onChange(of: startingVowel) { _, newValue in
            if let display = newValue {
                manager.jumpToVowel(display)
                startingVowel = nil
            }
        }
        .onChange(of: startingToneMark) { _, newValue in
            if let display = newValue {
                manager.jumpToToneMark(display)
                startingToneMark = nil
            }
        }
        .onChange(of: startingToneRule) { _, newValue in
            if let ruleId = newValue {
                manager.jumpToToneRule(ruleId)
                startingToneRule = nil
            }
        }
    }
}

#Preview {
    ContentView()
}

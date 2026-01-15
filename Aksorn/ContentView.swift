//
//  ContentView.swift
//  Aksorn
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
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .flashcards
    @State private var highlightedConsonant: String? = nil
    @State private var highlightedVowel: String? = nil
    @State private var flashcardStartingConsonant: String? = nil
    @State private var flashcardStartingVowel: String? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            FlashcardsView(
                highlightedConsonant: $highlightedConsonant,
                highlightedVowel: $highlightedVowel,
                startingConsonant: $flashcardStartingConsonant,
                startingVowel: $flashcardStartingVowel,
                selectedTab: $selectedTab
            )
            .tabItem {
                Label("Flashcards", systemImage: "rectangle.on.rectangle")
            }
            .tag(AppTab.flashcards)

            CheatsheetBrowserView(
                highlightedConsonant: $highlightedConsonant,
                highlightedVowel: $highlightedVowel,
                flashcardStartingConsonant: $flashcardStartingConsonant,
                flashcardStartingVowel: $flashcardStartingVowel,
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
    @Binding var startingConsonant: String?
    @Binding var startingVowel: String?
    @Binding var selectedTab: AppTab

    @State private var consonants: [Consonant] = []
    @State private var vowels: [Vowel] = []
    @State private var vowelCards: [VowelCard] = []
    @State private var currentType: FlashcardType = .consonant
    @State private var consonantIndex: Int = 0
    @State private var vowelIndex: Int = 0

    var body: some View {
        NavigationStack {
            if consonants.isEmpty || vowelCards.isEmpty {
                ContentUnavailableView(
                    "Loading...",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Loading flashcards")
                )
            } else {
                VStack(spacing: 0) {
                    // Type indicator
                    HStack {
                        Text(currentType == .consonant ? "Consonant" : "Vowel")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Current flashcard view
                    if currentType == .consonant {
                        ConsonantFlashcardView(
                            consonants: consonants,
                            currentIndex: $consonantIndex,
                            startingConsonant: $startingConsonant,
                            onViewInReference: { character in
                                highlightedConsonant = character
                                selectedTab = .reference
                            },
                            onNextCard: {
                                currentType = .vowel
                            }
                        )
                    } else {
                        VowelFlashcardView(
                            cards: vowelCards,
                            allVowels: vowels,
                            currentIndex: $vowelIndex,
                            startingVowel: $startingVowel,
                            onViewInReference: { vowel in
                                highlightedVowel = vowel
                                selectedTab = .reference
                            },
                            onNextCard: {
                                currentType = .consonant
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
    }
}

#Preview {
    ContentView()
}

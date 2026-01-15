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

struct ContentView: View {
    @State private var selectedTab: AppTab = .flashcards
    @State private var highlightedConsonant: String? = nil
    @State private var flashcardStartingConsonant: String? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            FlashcardsView(
                highlightedConsonant: $highlightedConsonant,
                startingConsonant: $flashcardStartingConsonant,
                selectedTab: $selectedTab
            )
            .tabItem {
                Label("Flashcards", systemImage: "rectangle.on.rectangle")
            }
            .tag(AppTab.flashcards)

            CheatsheetBrowserView(
                highlightedConsonant: $highlightedConsonant,
                flashcardStartingConsonant: $flashcardStartingConsonant,
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
    @Binding var startingConsonant: String?
    @Binding var selectedTab: AppTab
    @State private var consonants: [Consonant] = []

    var body: some View {
        NavigationStack {
            if consonants.isEmpty {
                ContentUnavailableView(
                    "Loading...",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Loading consonants")
                )
            } else {
                ConsonantFlashcardView(
                    consonants: consonants,
                    startingConsonant: $startingConsonant,
                    onViewInReference: { character in
                        highlightedConsonant = character
                        selectedTab = .reference
                    }
                )
            }
        }
        .onAppear {
            if consonants.isEmpty {
                consonants = Consonant.loadAll()
            }
        }
    }
}

#Preview {
    ContentView()
}

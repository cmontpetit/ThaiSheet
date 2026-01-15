//
//  ContentView.swift
//  Aksorn
//
//  Created by Claude Montpetit on 2026-01-11.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            FlashcardsView()
                .tabItem {
                    Label("Flashcards", systemImage: "rectangle.on.rectangle")
                }

            CheatsheetBrowserView()
                .tabItem {
                    Label("Reference", systemImage: "book")
                }
        }
    }
}

struct FlashcardsView: View {
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
                ConsonantFlashcardView(consonants: consonants)
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

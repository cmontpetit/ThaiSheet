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
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Flashcards",
                systemImage: "rectangle.on.rectangle",
                description: Text("Practice Thai characters with spaced repetition")
            )
            .navigationTitle("Flashcards")
        }
    }
}

#Preview {
    ContentView()
}

//
//  ThaiSheetApp.swift
//  ThaiSheet
//
//  Created by Claude Montpetit on 2026-01-11.
//

import SwiftUI

@main
struct ThaiSheetApp: App {
    @State private var settings = FlashcardSettings()

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings)
                .environment(\.locale, settings.resolvedLocale)
        }
    }
}

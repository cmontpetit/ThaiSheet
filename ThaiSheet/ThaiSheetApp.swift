//
//  ThaiSheetApp.swift
//  ThaiSheet
//
//  Created by Claude Montpetit on 2026-01-11.
//

import SwiftUI

@main
struct ThaiSheetApp: App {
    private let syncedStore: SyncedKeyValueStore
    private let thaiData = ThaiDataStore()
    @State private var settings: FlashcardSettings

    init() {
        let store = SyncedKeyValueStore()
        self.syncedStore = store
        _settings = State(initialValue: FlashcardSettings(defaults: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings, syncedStore: syncedStore)
                .environment(\.locale, settings.resolvedLocale)
                .environment(\.thaiData, thaiData)
        }
    }
}

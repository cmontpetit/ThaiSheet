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
    @State private var audioPlayer: AudioPlayer

    init() {
        let store = SyncedKeyValueStore()
        let settings = FlashcardSettings(defaults: store)
        self.syncedStore = store
        _settings = State(initialValue: settings)
        _audioPlayer = State(initialValue: AudioPlayer(audioSource: settings.audioSource, recordedVoice: settings.recordedVoice))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings, syncedStore: syncedStore)
                .environment(\.locale, settings.resolvedLocale)
                .environment(\.thaiData, thaiData)
                .environment(\.audioPlayer, audioPlayer)
                .onChange(of: settings.audioSource) { _, source in
                    audioPlayer.audioSource = source
                }
                .onChange(of: settings.recordedVoice) { _, voice in
                    audioPlayer.recordedVoice = voice
                }
        }
    }
}

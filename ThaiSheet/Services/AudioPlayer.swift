//
//  AudioPlayer.swift
//  ThaiSheet
//

import AVFoundation
import SwiftUI

enum SoundType: String {
    case consonant
    case vowel
    case cluster
    case toneMark = "tone_mark"
    case toneRule = "tone_rule"
}

/// Protocol for audio playback, enabling test mocking
protocol AudioPlaying {
    func play(_ type: SoundType, key: String)
    func hasSound(_ type: SoundType, key: String) -> Bool
}

// MARK: - Environment Key

private struct AudioPlayerKey: EnvironmentKey {
    static let defaultValue: AudioPlaying = AudioPlayer.shared
}

extension EnvironmentValues {
    var audioPlayer: AudioPlaying {
        get { self[AudioPlayerKey.self] }
        set { self[AudioPlayerKey.self] = newValue }
    }
}

// MARK: - AudioPlayer Implementation

class AudioPlayer: AudioPlaying {
    static let shared = AudioPlayer()
    private var player: AVAudioPlayer?

    private init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            // Use .playback to play sounds even when silent switch is on
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    func play(_ type: SoundType, key: String) {
        let filename = "cheat_sheet_\(type.rawValue)_\(key)"
        playFile(filename: filename)
    }

    func hasSound(_ type: SoundType, key: String) -> Bool {
        let filename = "cheat_sheet_\(type.rawValue)_\(key)"
        return Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "sounds") != nil ||
               Bundle.main.url(forResource: filename, withExtension: "mp3") != nil
    }

    private func playFile(filename: String) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "sounds") else {
            // Try without subdirectory
            guard let url = Bundle.main.url(forResource: filename, withExtension: "mp3") else {
                print("Sound file not found: \(filename).mp3")
                return
            }
            playURL(url)
            return
        }
        playURL(url)
    }

    private func playURL(_ url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            print("Error playing sound: \(error)")
        }
    }
}

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
    func speak(_ text: String)
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

class AudioPlayer: NSObject, AudioPlaying {
    static let shared = AudioPlayer()
    private var player: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        speechSynthesizer.delegate = self
        // Skip audio session configuration during unit tests to avoid CoreAudio crashes
        if NSClassFromString("XCTestCase") == nil {
            configureAudioSession()
        }
    }

    private func configureAudioSession() {
        do {
            // Mix with background audio (music) rather than interrupting it.
            // The session is activated on-demand when playing and deactivated after.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .duckOthers)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    func play(_ type: SoundType, key: String) {
        speechSynthesizer.stopSpeaking(at: .immediate)
        let filename = "cheat_sheet_\(type.rawValue)_\(key)"
        playFile(filename: filename)
    }

    func speak(_ text: String) {
        player?.stop()
        speechSynthesizer.stopSpeaking(at: .immediate)

        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error activating audio session for speech: \(error)")
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "th-TH")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        speechSynthesizer.speak(utterance)
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
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
        } catch {
            print("Error playing sound: \(error)")
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Deactivate session so background music can resume
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioPlayer: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

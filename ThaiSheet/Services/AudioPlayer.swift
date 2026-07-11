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
    case sampleWord = "sample_word"
}

enum AudioSource: String, CaseIterable, Identifiable {
    case recorded
    case device

    var id: String { rawValue }
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
    var audioSource: AudioSource

    init(audioSource: AudioSource = .recorded) {
        self.audioSource = audioSource
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
        switch effectiveAudioSource {
        case .recorded:
            speechSynthesizer.stopSpeaking(at: .immediate)
            playFile(filename: Self.filename(type, key: key))
        case .device:
            guard let text = Self.liveText(for: type, key: key) else { return }
            speak(text)
        }
    }

    func speak(_ text: String) {
        guard let voice = AVSpeechSynthesisVoice(language: "th-TH") else { return }
        player?.stop()
        speechSynthesizer.stopSpeaking(at: .immediate)

        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error activating audio session for speech: \(error)")
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        speechSynthesizer.speak(utterance)
    }

    func hasSound(_ type: SoundType, key: String) -> Bool {
        switch effectiveAudioSource {
        case .recorded:
            return Self.hasRecordedSound(type, key: key)
        case .device:
            return Self.liveText(for: type, key: key) != nil
        }
    }

    static var isThaiVoiceAvailable: Bool {
        AVSpeechSynthesisVoice(language: "th-TH") != nil
    }

    static func liveText(for type: SoundType, key: String) -> String? {
        switch type {
        case .consonant:
            return consonantNamesByCharacter[key]
        case .vowel:
            guard key != "ฤ-" else { return nil }
            return key.hasSuffix("-") ? String(key.dropLast()) : key
        case .cluster:
            return key.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        case .toneMark, .toneRule, .sampleWord:
            return key
        }
    }

    private var effectiveAudioSource: AudioSource {
        audioSource == .device && Self.isThaiVoiceAvailable ? .device : .recorded
    }

    private static let consonantNamesByCharacter = Dictionary(
        uniqueKeysWithValues: Consonant.loadAll().map { ($0.character, $0.name) }
    )

    private static func filename(_ type: SoundType, key: String) -> String {
        "cheat_sheet_\(type.rawValue)_\(key)"
    }

    private static func hasRecordedSound(_ type: SoundType, key: String) -> Bool {
        let filename = filename(type, key: key)
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

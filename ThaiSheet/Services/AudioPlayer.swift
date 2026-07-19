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

/// Which bundled recorded-voice set to play. The app bundle flattens all resources
/// to the root (the synchronized file group does not preserve subfolders), so the
/// voice sets are disambiguated by a filename suffix rather than a folder: the current
/// shipping voice keeps the unsuffixed names, alternates append `_kore` / `_matilda`.
/// This is a DEBUG-only comparison aid; release ships a single voice.
enum RecordedVoice: String, CaseIterable, Identifiable {
    case current      // Google Neural2-C — the shipping bundled voice
    case kore         // Google Chirp3-HD-Kore
    case matilda      // ElevenLabs Matilda (eleven_v3)

    var id: String { rawValue }

    /// Suffix appended to the base `cheat_sheet_<type>_<key>` filename.
    var filenameSuffix: String {
        switch self {
        case .current: return ""
        case .kore: return "_kore"
        case .matilda: return "_matilda"
        }
    }

    var displayName: String {
        switch self {
        case .current: return "Google Neural2-C"
        case .kore: return "Google Chirp3-HD Kore"
        case .matilda: return "ElevenLabs Matilda"
        }
    }
}

/// Protocol for audio playback, enabling test mocking
protocol AudioPlaying {
    func play(_ type: SoundType, key: String)
    func speak(_ text: String)
    func hasSound(_ type: SoundType, key: String) -> Bool
}

// MARK: - Environment Key

private struct AudioPlayerKey: EnvironmentKey {
    static let defaultValue: AudioPlaying = NoOpAudioPlayer()
}

private struct NoOpAudioPlayer: AudioPlaying {
    func play(_ type: SoundType, key: String) {}
    func speak(_ text: String) {}
    func hasSound(_ type: SoundType, key: String) -> Bool { false }
}

extension EnvironmentValues {
    var audioPlayer: AudioPlaying {
        get { self[AudioPlayerKey.self] }
        set { self[AudioPlayerKey.self] = newValue }
    }
}

// MARK: - AudioPlayer Implementation

class AudioPlayer: NSObject, AudioPlaying {
    private var player: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    var audioSource: AudioSource
    var recordedVoice: RecordedVoice

    init(audioSource: AudioSource = .recorded, recordedVoice: RecordedVoice = .current) {
        self.audioSource = audioSource
        self.recordedVoice = recordedVoice
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
            playRecorded(type, key: key)
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
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)
    }

    func hasSound(_ type: SoundType, key: String) -> Bool {
        switch effectiveAudioSource {
        case .recorded:
            return Self.hasRecordedSound(type, key: key, voice: recordedVoice)
        case .device:
            return Self.liveText(for: type, key: key) != nil
        }
    }

    static var isThaiVoiceAvailable: Bool {
        AVSpeechSynthesisVoice(language: "th-TH") != nil
    }

    static func resolvedAudioSource(
        _ requestedSource: AudioSource,
        isThaiVoiceAvailable: Bool
    ) -> AudioSource {
        requestedSource == .device && !isThaiVoiceAvailable ? .recorded : requestedSource
    }

    static func liveText(for type: SoundType, key: String) -> String? {
        switch type {
        case .consonant:
            return consonantNamesByCharacter[key]
        case .vowel:
            return key
        case .cluster:
            return key.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        case .toneMark, .toneRule, .sampleWord:
            return key
        }
    }

    private var effectiveAudioSource: AudioSource {
        Self.resolvedAudioSource(audioSource, isThaiVoiceAvailable: Self.isThaiVoiceAvailable)
    }

    private static let consonantNamesByCharacter = Dictionary(
        uniqueKeysWithValues: Consonant.loadAll().map {
            ($0.character, $0.name.replacingOccurrences(of: " ", with: ""))
        }
    )

    private static func filename(_ type: SoundType, key: String, voice: RecordedVoice) -> String {
        "cheat_sheet_\(type.rawValue)_\(key)\(voice.filenameSuffix)"
    }

    private static func recordedURL(_ filename: String) -> URL? {
        // Resources flatten to the bundle root; keep the subdirectory lookup first for safety.
        Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "sounds")
            ?? Bundle.main.url(forResource: filename, withExtension: "mp3")
    }

    private static func hasRecordedSound(_ type: SoundType, key: String, voice: RecordedVoice) -> Bool {
        recordedURL(filename(type, key: key, voice: voice)) != nil ||
            recordedURL(filename(type, key: key, voice: .current)) != nil
    }

    private func playRecorded(_ type: SoundType, key: String) {
        // Prefer the selected voice; fall back to the current set if a clip is missing
        // (e.g. an alternate voice that could not synthesize a rare glyph).
        let name = Self.filename(type, key: key, voice: recordedVoice)
        guard let url = Self.recordedURL(name)
            ?? Self.recordedURL(Self.filename(type, key: key, voice: .current)) else {
            print("Sound file not found: \(name).mp3")
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

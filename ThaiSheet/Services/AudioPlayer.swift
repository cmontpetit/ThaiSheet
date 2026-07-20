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

/// A selectable pronunciation voice. The three recorded sets are bundled MP3s
/// (disambiguated by a filename suffix — the app bundle flattens resources to the
/// root, so folders can't); `.device` is the live Apple system voice (availability
/// is device-dependent, so it's only offered when a Thai system voice is installed).
/// `Codable` so the per-item override map persists as JSON.
/// (Named `RecordedVoice` for history; `.device` is the one non-recorded member.)
enum RecordedVoice: String, CaseIterable, Identifiable, Codable {
    case neural2      // Google Neural2-C
    case kore         // Google Chirp3-HD-Kore
    case matilda      // ElevenLabs Matilda (eleven_v3)
    case device       // Apple system voice (AVSpeechSynthesizer)

    private static let legacyCurrentRawValue = "current"

    var id: String { rawValue }

    /// The bundled recorded voices (everything but the live device voice).
    static var recordedCases: [RecordedVoice] { [.neural2, .kore, .matilda] }

    var isDevice: Bool { self == .device }

    /// Suffix appended to the base `cheat_sheet_<type>_<key>` filename. Unused for
    /// `.device` (which never plays a bundled file).
    var filenameSuffix: String {
        switch self {
        case .neural2: return "_neural2"
        case .kore: return "_kore"
        case .matilda: return "_matilda"
        case .device: return ""
        }
    }

    var displayName: String {
        switch self {
        case .neural2: return "Google Neural2-C"
        case .kore: return "Google Chirp3-HD Kore"
        case .matilda: return "ElevenLabs Matilda"
        case .device: return String(localized: "Device voice (system)", bundle: .appLanguage)
        }
    }

    /// Accept the pre-rename `current` value without keeping that misleading name in
    /// the model. New values always encode as `neural2`.
    static func persistedValue(_ value: String) -> RecordedVoice? {
        value == legacyCurrentRawValue ? .neural2 : RecordedVoice(rawValue: value)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let voice = Self.persistedValue(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown recorded voice: \(value)"
            )
        }
        self = voice
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Protocol for audio playback, enabling test mocking
protocol AudioPlaying {
    /// `itemID` selects a per-item voice override; `previewVoice` forces a specific
    /// recorded voice (for auditioning in the override picker).
    func play(_ type: SoundType, key: String, itemID: String?, previewVoice: RecordedVoice?)
    func speak(_ text: String)
    func hasSound(_ type: SoundType, key: String) -> Bool
    /// Whether a specific voice has this exact clip (no fallback) — for the picker.
    func hasRecordedSound(_ type: SoundType, key: String, voice: RecordedVoice) -> Bool
}

extension AudioPlaying {
    /// Convenience overloads so call sites need only what they use (protocol
    /// requirements can't carry defaults through the existential).
    func play(_ type: SoundType, key: String) {
        play(type, key: key, itemID: nil, previewVoice: nil)
    }
    func play(_ type: SoundType, key: String, itemID: String?) {
        play(type, key: key, itemID: itemID, previewVoice: nil)
    }
}

// MARK: - Environment Key

private struct AudioPlayerKey: EnvironmentKey {
    static let defaultValue: AudioPlaying = NoOpAudioPlayer()
}

private struct NoOpAudioPlayer: AudioPlaying {
    func play(_ type: SoundType, key: String, itemID: String?, previewVoice: RecordedVoice?) {}
    func speak(_ text: String) {}
    func hasSound(_ type: SoundType, key: String) -> Bool { false }
    func hasRecordedSound(_ type: SoundType, key: String, voice: RecordedVoice) -> Bool { false }
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
    var recordedVoice: RecordedVoice
    /// Per-item voice overrides, keyed by `FlashcardType.cardId(for:)`. Loaded at init
    /// (onChange does not fire for the already-persisted value at launch).
    var voiceOverrides: [String: RecordedVoice]

    init(
        recordedVoice: RecordedVoice = .matilda,
        voiceOverrides: [String: RecordedVoice] = [:]
    ) {
        self.recordedVoice = recordedVoice
        self.voiceOverrides = voiceOverrides
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

    func play(_ type: SoundType, key: String, itemID: String? = nil, previewVoice: RecordedVoice? = nil) {
        let voice = resolvedVoice(for: itemID, previewVoice: previewVoice)
        if voice == .device {
            // Live Apple voice; if a Thai system voice isn't installed, fall back to
            // the recorded default so the item still plays.
            if Self.isThaiVoiceAvailable, let text = Self.liveText(for: type, key: key) {
                speak(text)
                return
            }
            speechSynthesizer.stopSpeaking(at: .immediate)
            playRecorded(type, key: key, voice: .matilda)
            return
        }
        speechSynthesizer.stopSpeaking(at: .immediate)
        playRecorded(type, key: key, voice: voice)
    }

    /// Precedence: an explicit preview wins, then a per-item override, then the default.
    func resolvedVoice(for itemID: String?, previewVoice: RecordedVoice?) -> RecordedVoice {
        previewVoice ?? itemID.flatMap { voiceOverrides[$0] } ?? recordedVoice
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
        if recordedVoice == .device,
           Self.isThaiVoiceAvailable,
           Self.liveText(for: type, key: key) != nil {
            return true
        }
        return Self.recordedPlaybackOrder(for: recordedVoice).contains {
            Self.recordedClipExists(type, key: key, voice: $0)
        }
    }

    /// Whether a *specific* voice can play this exact item, with no fallback — the
    /// override picker uses this to disable a voice that can't. Device availability is
    /// "a Thai system voice is installed and the item has speakable text."
    func hasRecordedSound(_ type: SoundType, key: String, voice: RecordedVoice) -> Bool {
        if voice == .device {
            return Self.isThaiVoiceAvailable && Self.liveText(for: type, key: key) != nil
        }
        return Self.recordedClipExists(type, key: key, voice: voice)
    }

    static var isThaiVoiceAvailable: Bool {
        AVSpeechSynthesisVoice(language: "th-TH") != nil
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

    /// Exact existence for one voice, no fallback.
    private static func recordedClipExists(_ type: SoundType, key: String, voice: RecordedVoice) -> Bool {
        recordedURL(filename(type, key: key, voice: voice)) != nil
    }

    /// The selected voice is preferred. Matilda is the app's recorded fallback;
    /// Neural2 is retained only as a final safety net if Matilda is missing a clip.
    static func recordedPlaybackOrder(for voice: RecordedVoice) -> [RecordedVoice] {
        let preferred = voice == .device ? RecordedVoice.matilda : voice
        return [preferred, .matilda, .neural2].reduce(into: []) { order, candidate in
            if !order.contains(candidate) { order.append(candidate) }
        }
    }

    private func playRecorded(_ type: SoundType, key: String, voice: RecordedVoice) {
        let order = Self.recordedPlaybackOrder(for: voice)
        guard let url = order.lazy.compactMap({ candidate in
            Self.recordedURL(Self.filename(type, key: key, voice: candidate))
        }).first else {
            let attempted = order.map { Self.filename(type, key: key, voice: $0) }.joined(separator: ", ")
            print("Sound file not found (tried: \(attempted); all with .mp3 extension)")
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

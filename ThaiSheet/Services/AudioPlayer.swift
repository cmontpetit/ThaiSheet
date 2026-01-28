//
//  AudioPlayer.swift
//  ThaiSheet
//

import AVFoundation

class AudioPlayer {
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

    func playConsonantSound(for character: String) {
        let filename = "cheat_sheet_consonant_\(character)"
        play(filename: filename)
    }

    func playVowelSound(for form: String) {
        let filename = "cheat_sheet_vowel_\(form)"
        play(filename: filename)
    }

    func playClusterSound(for cluster: String) {
        let filename = "cheat_sheet_cluster_\(cluster)"
        play(filename: filename)
    }

    func playToneMarkSound(for mark: String) {
        let filename = "cheat_sheet_tone_mark_\(mark)"
        play(filename: filename)
    }

    func playToneRuleSound(for sampleWord: String) {
        let filename = "cheat_sheet_tone_rule_\(sampleWord)"
        play(filename: filename)
    }

    private func play(filename: String) {
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

    func hasConsonantSound(for character: String) -> Bool {
        let filename = "cheat_sheet_consonant_\(character)"
        return Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "sounds") != nil ||
               Bundle.main.url(forResource: filename, withExtension: "mp3") != nil
    }

    func hasVowelSound(for form: String) -> Bool {
        let filename = "cheat_sheet_vowel_\(form)"
        return Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "sounds") != nil ||
               Bundle.main.url(forResource: filename, withExtension: "mp3") != nil
    }

    func hasToneMarkSound(for mark: String) -> Bool {
        let filename = "cheat_sheet_tone_mark_\(mark)"
        return Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "sounds") != nil ||
               Bundle.main.url(forResource: filename, withExtension: "mp3") != nil
    }

    func hasToneRuleSound(for sampleWord: String) -> Bool {
        let filename = "cheat_sheet_tone_rule_\(sampleWord)"
        return Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "sounds") != nil ||
               Bundle.main.url(forResource: filename, withExtension: "mp3") != nil
    }

    func hasClusterSound(for display: String) -> Bool {
        let filename = "cheat_sheet_cluster_\(display)"
        return Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "sounds") != nil ||
               Bundle.main.url(forResource: filename, withExtension: "mp3") != nil
    }
}

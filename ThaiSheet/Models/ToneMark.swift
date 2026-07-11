//
//  ToneMark.swift
//  ThaiSheet
//

import Foundation
import SwiftUI

/// A tone mark and the tone it produces on each consonant class.
/// A nil tone means the mark is not used with that class (๊/๋ are
/// mid-class only). Unmarked syllables are NOT represented here — they
/// follow the tone-rules table.
struct ToneMarkSamples: Codable {
    let low: ReferenceSampleWord?
    let mid: ReferenceSampleWord?
    let high: ReferenceSampleWord?
}

struct ToneMark: Codable, Identifiable {
    let mark: String
    let onLow: String?
    let onMid: String?
    let onHigh: String?
    let samples: ToneMarkSamples?

    var id: String { mark }

    /// Fixed example consonants per class, matching the reference table,
    /// the flashcards, and the bundled sound files
    static let lowConsonant = "ค"
    static let midConsonant = "ก"
    static let highConsonant = "ข"

    /// One reference-table column per class, in Low/Mid/High order.
    /// `tone` is nil where the mark doesn't apply.
    var classEntries: [ClassEntry] {
        [
            ClassEntry(className: "Low", tone: onLow, consonant: Self.lowConsonant, mark: mark),
            ClassEntry(className: "Mid", tone: onMid, consonant: Self.midConsonant, mark: mark),
            ClassEntry(className: "High", tone: onHigh, consonant: Self.highConsonant, mark: mark),
        ]
    }

    struct ClassEntry: Identifiable {
        let className: String
        let tone: String?
        let consonant: String
        let mark: String

        var id: String { className }
        /// Compact display without vowel (e.g. "ค่")
        var display: String { consonant + mark }
        /// Full syllable with า, used for pronunciation and as the card id (e.g. "ค่า")
        var soundKey: String { consonant + mark + "า" }
    }

    func sampleWord(for soundKey: String) -> ReferenceSampleWord? {
        if soundKey == Self.lowConsonant + mark + "า" {
            return samples?.low
        }
        if soundKey == Self.midConsonant + mark + "า" {
            return samples?.mid
        }
        if soundKey == Self.highConsonant + mark + "า" {
            return samples?.high
        }
        return nil
    }

    func toneColor(for tone: String) -> Color {
        ThaiColors.forTone(tone)
    }
}

struct ToneMarksData: Codable {
    let toneMarks: [ToneMark]
}

extension ToneMark {
    static func loadAll() -> [ToneMark] {
        BundleLoader.load("tone-marks", as: ToneMarksData.self, keyPath: \.toneMarks)
    }
}

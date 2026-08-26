//
//  ToneRule.swift
//  ThaiSheet
//

import Foundation
import SwiftUI

struct ToneSample: Codable {
    /// Stable identifier from the data file, unique within its rule. Opaque and
    /// never displayed: correcting a sample word must not orphan the progress
    /// stored against it. Never rename one, and give a new sample a new id
    /// rather than reusing a retired one.
    let id: String
    let full: String
    let focus: String
    let note: LocalizedText?
    let romanization: String?
    let meaning: LocalizedText?

    init(
        id: String,
        full: String,
        focus: String,
        note: LocalizedText? = nil,
        romanization: String? = nil,
        meaning: LocalizedText? = nil
    ) {
        self.id = id
        self.full = full
        self.focus = focus
        self.note = note
        self.romanization = romanization
        self.meaning = meaning
    }
}

struct ToneRule: Codable, Identifiable {
    let initialConsonant: String
    let vowelDuration: String
    let end: String
    let tone: String
    let samples: [ToneSample]?

    var id: String { "\(initialConsonant)-\(vowelDuration)-\(end)" }

    // First sample for display in the tone rules table
    var primarySample: ToneSample? { samples?.first }

    var consonantColor: Color {
        guard let cls = ConsonantClass(rawValue: initialConsonant.lowercased()) else {
            return Color.clear
        }
        return cls.color
    }

    var toneColor: Color {
        ThaiColors.forTone(tone)
    }
}

struct ToneRulesData: Codable {
    let toneRules: [ToneRule]
}

extension ToneRule {
    /// The rows, or the reason they could not be loaded. `ThaiDataStore` uses
    /// this so a packaging failure can be shown instead of silently vanishing.
    static func loadAll(provider: ResourceProviding) -> Result<[ToneRule], DatasetLoadError> {
        BundleLoader.load("tone-rules", as: ToneRulesData.self, keyPath: \.toneRules, provider: provider)
    }

    static func loadAll() -> [ToneRule] {
        BundleLoader.items("tone-rules", as: ToneRulesData.self, keyPath: \.toneRules)
    }
}

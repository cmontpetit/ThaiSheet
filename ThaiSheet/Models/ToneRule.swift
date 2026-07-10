//
//  ToneRule.swift
//  ThaiSheet
//

import Foundation
import SwiftUI

struct ToneSample: Codable {
    let full: String
    let focus: String
    let note: LocalizedText?
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
    static func loadAll() -> [ToneRule] {
        BundleLoader.load("tone-rules", as: ToneRulesData.self, keyPath: \.toneRules)
    }
}

//
//  ToneMark.swift
//  ThaiSheet
//

import Foundation
import SwiftUI

struct ToneMark: Codable, Identifiable {
    let mark: String
    let onLowConsonant: String
    let onMidHighConsonant: String

    var id: String { mark.isEmpty ? "none" : mark }

    // Display with low class consonant (ค) - no vowel for compact reference display
    var withLowConsonant: String { "ค" + mark }

    // Display with mid class consonant (ก) - no vowel for compact reference display
    var withMidHighConsonant: String { "ก" + mark }

    // Sound lookup key with vowel า for pronunciation
    var soundKeyLow: String { "ค" + mark + "า" }
    var soundKeyMidHigh: String { "ก" + mark + "า" }

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

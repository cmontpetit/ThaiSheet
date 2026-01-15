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

    // Display with low class consonant (ค)
    var withLowConsonant: String { "ค" + mark }

    // Display with mid class consonant (ก)
    var withMidHighConsonant: String { "ก" + mark }

    func toneColor(for tone: String) -> Color {
        switch tone {
        case "High": return Color.red.opacity(0.2)
        case "Rising": return Color.red.opacity(0.2)
        case "Mid": return Color.clear
        case "Low": return Color.green.opacity(0.2)
        case "Falling": return Color.green.opacity(0.2)
        case "n/a": return Color.gray.opacity(0.1)
        default: return Color.clear
        }
    }
}

struct ToneMarksData: Codable {
    let toneMarks: [ToneMark]
}

extension ToneMark {
    static func loadAll() -> [ToneMark] {
        guard let url = Bundle.main.url(forResource: "tone-marks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ToneMarksData.self, from: data) else {
            return []
        }
        return decoded.toneMarks
    }
}

//
//  ToneRule.swift
//  ThaiSheet
//

import Foundation
import SwiftUI

struct ToneRule: Codable, Identifiable {
    let initialConsonant: String
    let vowelDuration: String
    let end: String
    let tone: String
    let sampleWord: String?

    var id: String { "\(initialConsonant)-\(vowelDuration)-\(end)" }

    var consonantColor: Color {
        switch initialConsonant {
        case "Low": return Color.green.opacity(0.3)
        case "Mid": return Color.yellow.opacity(0.3)
        case "High": return Color.red.opacity(0.3)
        default: return Color.clear
        }
    }

    var toneColor: Color {
        switch tone {
        case "High": return Color.red.opacity(0.2)
        case "Rising": return Color.red.opacity(0.2)
        case "Mid": return Color.clear
        case "Low": return Color.green.opacity(0.2)
        case "Falling": return Color.green.opacity(0.2)
        default: return Color.clear
        }
    }
}

struct ToneRulesData: Codable {
    let toneRules: [ToneRule]
}

extension ToneRule {
    static func loadAll() -> [ToneRule] {
        guard let url = Bundle.main.url(forResource: "tone-rules", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ToneRulesData.self, from: data) else {
            return []
        }
        return decoded.toneRules
    }
}

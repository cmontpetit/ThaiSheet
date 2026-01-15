//
//  ToneMark.swift
//  ThaiSheet
//

import Foundation
import SwiftUI

struct ToneMark: Codable, Identifiable {
    let toneMark: String
    let onLowConsonant: String
    let onMidHighConsonant: String

    var id: String { toneMark }

    func toneColor(for tone: String) -> Color {
        switch tone {
        case "High": return Color.red.opacity(0.2)
        case "Rising": return Color.red.opacity(0.2)
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

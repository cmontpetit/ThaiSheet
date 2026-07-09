//
//  ThaiColors.swift
//  ThaiSheet
//

import SwiftUI

enum ThaiColors {
    /// Color for a Thai tone name. Each tone gets its own hue so a chip is
    /// identifiable by color alone, from a family deliberately distinct from
    /// the consonant-class green/yellow/red; cool hues end low, warm end high.
    static func forTone(_ tone: String) -> Color {
        switch tone {
        case "Low": return Color.blue.opacity(0.2)
        case "Mid": return Color.clear
        case "High": return Color.orange.opacity(0.25)
        case "Falling": return Color.purple.opacity(0.25)
        case "Rising": return Color.teal.opacity(0.25)
        case "n/a": return Color.gray.opacity(0.1)
        default: return Color.clear
        }
    }

    /// Selection-button background for a tone value (gray when the tone has no color)
    static func toneButtonBackground(_ tone: String) -> AnyShapeStyle {
        let color = forTone(tone)
        return AnyShapeStyle(color == .clear ? Color(.systemGray5) : color)
    }

    /// Localized display name for a tone data identifier (e.g. "Falling")
    static func toneName(_ tone: String) -> String {
        String(localized: String.LocalizationValue(tone), bundle: .appLanguage)
    }

    /// Diacritic plus localized name (e.g. "◌̂ Falling"), pairing the symbol
    /// with its meaning in result summaries
    static func toneDisplay(_ tone: String) -> String {
        "\(toneDiacritic(tone)) \(toneName(tone))"
    }

    /// Paiboon-style tone diacritic on the ◌ placeholder, matching the
    /// transcription convention (mid tone is unmarked). Language-neutral.
    static func toneDiacritic(_ tone: String) -> String {
        switch tone {
        case "Low": return "◌\u{0300}"
        case "Mid": return "◌"
        case "High": return "◌\u{0301}"
        case "Falling": return "◌\u{0302}"
        case "Rising": return "◌\u{030C}"
        default: return tone
        }
    }
}

//
//  ThaiColors.swift
//  ThaiSheet
//

import SwiftUI

enum ThaiColors {
    /// Color for a Thai tone name (High, Rising, Mid, Low, Falling)
    static func forTone(_ tone: String) -> Color {
        switch tone {
        case "High", "Rising": return Color.red.opacity(0.2)
        case "Mid": return Color.clear
        case "Low", "Falling": return Color.green.opacity(0.2)
        case "n/a": return Color.gray.opacity(0.1)
        default: return Color.clear
        }
    }

    /// Selection-button background for a tone value (gray when the tone has no color)
    static func toneButtonBackground(_ tone: String) -> AnyShapeStyle {
        let color = forTone(tone)
        return AnyShapeStyle(color == .clear ? Color(.systemGray5) : color)
    }

    /// One-letter tone code matching the transcription markers (ᴸ ᴹ ᴴ ᶠ ᴿ)
    static func toneAbbreviation(_ tone: String) -> String {
        String(tone.prefix(1))
    }
}

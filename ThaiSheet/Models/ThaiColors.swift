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
}

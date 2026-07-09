//
//  Consonant.swift
//  ThaiSheet
//

import Foundation
import SwiftUI

enum ConsonantClass: String, Codable, CaseIterable {
    case low
    case mid
    case high

    var label: String {
        switch self {
        case .low: return "L"
        case .mid: return "M"
        case .high: return "H"
        }
    }

    var displayName: String {
        switch self {
        case .low: return String(localized: "Low", bundle: .appLanguage)
        case .mid: return String(localized: "Mid", bundle: .appLanguage)
        case .high: return String(localized: "High", bundle: .appLanguage)
        }
    }

    var color: Color {
        switch self {
        case .low: return Color.green.opacity(0.3)
        case .mid: return Color.yellow.opacity(0.3)
        case .high: return Color.red.opacity(0.3)
        }
    }
}

enum ConsonantUsage: String, Codable {
    case common
    case uncommon
    case rare
    case ancient

    /// Localized display label (lowercase, shown as a row annotation)
    var label: String {
        switch self {
        case .common: return ""
        case .uncommon: return String(localized: "uncommon", bundle: .appLanguage)
        case .rare: return String(localized: "rare", bundle: .appLanguage)
        case .ancient: return String(localized: "ancient", bundle: .appLanguage)
        }
    }
}

struct ConsonantSounds: Codable {
    let initial: String
    let final: String
}

struct ConsonantSoundsContainer: Codable {
    let en: ConsonantSounds
}

struct Consonant: Codable, Identifiable {
    let character: String
    let name: String
    let transcription: String
    let `class`: ConsonantClass
    let usage: ConsonantUsage
    let sounds: ConsonantSoundsContainer

    var id: String { character }

    var initialSound: String { sounds.en.initial }
    var finalSound: String { sounds.en.final }
    var consonantClass: ConsonantClass { `class` }
}

struct ConsonantsData: Codable {
    let consonants: [Consonant]
}

extension Consonant {
    static func loadAll() -> [Consonant] {
        BundleLoader.load("consonants", as: ConsonantsData.self, keyPath: \.consonants)
    }
}

//
//  FlashcardItem.swift
//  ThaiSheet
//

import Foundation

extension FlashcardType {
    /// Prefix of persisted card-progress IDs. These are stored in user data
    /// (UserDefaults/iCloud) — never rename.
    var idPrefix: String {
        switch self {
        case .consonant: "consonant"
        case .vowel: "vowel"
        case .toneMark: "toneMark"
        case .toneRule: "toneRule"
        case .cluster: "cluster"
        }
    }

    /// Persisted progress ID for a card key (the underlying model's `id`).
    /// Single source of truth — use this instead of building "type-key" strings.
    func cardId(for key: String) -> String {
        "\(idPrefix)-\(key)"
    }

    /// Prefix of progress IDs for consonant cards that skip the name question.
    /// Stored in user data (UserDefaults/iCloud) — never rename.
    static let consonantSoundIDPrefix = "consonantSound"

    /// Persisted progress ID for a consonant card. Cards that quiz the name keep
    /// the original `consonant-` IDs; name-free cards have their own progress.
    static func consonantCardId(for key: String, includesName: Bool) -> String {
        includesName ? FlashcardType.consonant.cardId(for: key) : "\(consonantSoundIDPrefix)-\(key)"
    }
}

/// A unified wrapper for all flashcard types
enum FlashcardItem: Identifiable {
    case consonant(Consonant, includesName: Bool)
    case vowel(VowelCard)
    case toneMark(ToneMarkCard)
    case toneRule(ToneRuleCard)
    case cluster(Cluster)

    var id: String {
        switch self {
        case .consonant(let c, let includesName):
            return FlashcardType.consonantCardId(for: c.id, includesName: includesName)
        case .vowel(let v): return FlashcardType.vowel.cardId(for: v.id)
        case .toneMark(let t): return FlashcardType.toneMark.cardId(for: t.id)
        case .toneRule(let t): return FlashcardType.toneRule.cardId(for: t.id)
        case .cluster(let c): return FlashcardType.cluster.cardId(for: c.id)
        }
    }

    var type: FlashcardType {
        switch self {
        case .consonant: return .consonant
        case .vowel: return .vowel
        case .toneMark: return .toneMark
        case .toneRule: return .toneRule
        case .cluster: return .cluster
        }
    }
}

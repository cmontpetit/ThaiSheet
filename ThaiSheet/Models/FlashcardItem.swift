//
//  FlashcardItem.swift
//  ThaiSheet
//

import Foundation

/// A unified wrapper for all flashcard types
enum FlashcardItem: Identifiable {
    case consonant(Consonant)
    case vowel(VowelCard)
    case toneMark(ToneMarkCard)
    case toneRule(ToneRuleCard)

    var id: String {
        switch self {
        case .consonant(let c): return "consonant-\(c.id)"
        case .vowel(let v): return "vowel-\(v.id)"
        case .toneMark(let t): return "toneMark-\(t.id)"
        case .toneRule(let t): return "toneRule-\(t.id)"
        }
    }

    var type: FlashcardType {
        switch self {
        case .consonant: return .consonant
        case .vowel: return .vowel
        case .toneMark: return .toneMark
        case .toneRule: return .toneRule
        }
    }
}

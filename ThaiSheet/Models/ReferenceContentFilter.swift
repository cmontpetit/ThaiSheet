//
//  ReferenceContentFilter.swift
//  ThaiSheet
//

import Foundation

/// The Content toggles ("Uncommon, rare & ancient" consonants, "Uncommon,
/// rare & archaic" vowels) as the Reference tab applies them. Flashcards apply
/// the same settings through `FlashcardSettings.isConsonantEnabled` /
/// `isVowelCardEnabled`. The browser passes `.all` while searching, so search
/// still finds everything, and an explicit jump target stays visible.
struct ReferenceContentFilter {
    let showsUncommonConsonants: Bool
    let showsUncommonVowels: Bool
    /// Items a jump asked for, keyed like the browser's highlights.
    private(set) var revealed: [FlashcardType: String] = [:]

    static let all = ReferenceContentFilter(showsUncommonConsonants: true, showsUncommonVowels: true)

    init(showsUncommonConsonants: Bool, showsUncommonVowels: Bool) {
        self.showsUncommonConsonants = showsUncommonConsonants
        self.showsUncommonVowels = showsUncommonVowels
    }

    init(settings: FlashcardSettings) {
        self.init(
            showsUncommonConsonants: settings.uncommonConsonants,
            showsUncommonVowels: settings.uncommonVowels
        )
    }

    func revealing(_ highlighted: [FlashcardType: String]) -> ReferenceContentFilter {
        var copy = self
        copy.revealed = highlighted
        return copy
    }

    func includes(_ consonant: Consonant) -> Bool {
        showsUncommonConsonants || consonant.usage == .common || revealed[.consonant] == consonant.character
    }

    func includes(_ vowel: Vowel) -> Bool {
        showsUncommonVowels || !vowel.isUncommon
            || (revealed[.vowel].map { vowel.allForms.contains($0) } ?? false)
    }
}

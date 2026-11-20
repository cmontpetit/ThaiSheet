//
//  ReferenceJumpTarget.swift
//  ThaiSheet
//

import Foundation

/// The row an explicit jump asked for (flashcard "View in Reference", Tone
/// Finder "Show in the table"), keyed like the browser's `highlighted`.
/// A saved search must not hide it: while searching, each section shows its
/// search matches plus this row. The query itself is unchanged.
struct ReferenceJumpTarget {
    let highlighted: [FlashcardType: String]

    func contains(_ consonant: Consonant) -> Bool {
        highlighted[.consonant] == consonant.character
    }

    /// The row whose forms contain the highlighted written form.
    func contains(_ vowel: Vowel) -> Bool {
        guard let form = highlighted[.vowel] else { return false }
        return vowel.allForms.contains(form)
    }

    /// The row with a class entry for the highlighted syllable (ค่า): the
    /// key flashcards and the Tone Finder pass.
    func contains(_ mark: ToneMark) -> Bool {
        guard let key = highlighted[.toneMark] else { return false }
        return mark.classEntries.contains { $0.soundKey == key }
    }

    func contains(_ rule: ToneRule) -> Bool {
        highlighted[.toneRule] == rule.id
    }

    func contains(_ cluster: Cluster) -> Bool {
        highlighted[.cluster] == cluster.id
    }

    /// Search results for one section: the items matching the query, plus the
    /// jump target, in the list's order.
    static func searchResults<Item>(
        _ items: [Item],
        target isTarget: (Item) -> Bool,
        matching matches: (Item) -> Bool
    ) -> [Item] {
        items.filter { isTarget($0) || matches($0) }
    }
}

//
//  ReferenceBookScope.swift
//  ThaiSheet
//

import Foundation

/// The chapter scope as the Reference tab applies it: which rows, vowel forms,
/// and tone entries the book has introduced. Inactive (everything visible)
/// when the scope is Off or the mapping failed to load. The browser passes
/// `.inactive` while searching, since search includes all chapters.
struct ReferenceBookScope {
    let scope: BookScope
    let map: BookChapterMap?
    /// Items an explicit jump asked for (Tone Finder "Show in the table",
    /// "View in Reference" from a card), keyed like the browser's highlights.
    /// They stay visible beyond the chapter; the saved chapter is unchanged.
    private(set) var revealed: [FlashcardType: String] = [:]

    static let inactive = ReferenceBookScope(scope: BookScope(upTo: nil, includesNotInBook: true), map: nil)

    init(scope: BookScope, map: BookChapterMap?) {
        self.scope = scope
        self.map = map
    }

    init(settings: FlashcardSettings, map: BookChapterMap?) {
        self.init(scope: BookScope(settings: settings, map: map), map: map)
    }

    var isActive: Bool { scope.isActive && map != nil }

    func revealing(_ highlighted: [FlashcardType: String]) -> ReferenceBookScope {
        var copy = self
        copy.revealed = highlighted
        return copy
    }

    func includes(_ consonant: Consonant) -> Bool {
        guard isActive, let map else { return true }
        return scope.includes(map.placement(of: consonant)) || revealed[.consonant] == consonant.character
    }

    func includes(_ cluster: Cluster) -> Bool {
        guard isActive, let map else { return true }
        return scope.includes(map.placement(of: cluster)) || revealed[.cluster] == cluster.id
    }

    /// A tone-rule row shows when any of its samples is in scope.
    func includes(_ rule: ToneRule) -> Bool {
        guard isActive, let map else { return true }
        if revealed[.toneRule] == rule.id { return true }
        guard let samples = rule.samples, !samples.isEmpty else { return scope.includes(nil) }
        return samples.contains { scope.includes(map.placement(of: rule, sample: $0)) }
    }

    func includes(_ mark: ToneMark, className: String) -> Bool {
        guard isActive, let map else { return true }
        return scope.includes(map.placement(of: mark, className: className))
    }

    /// A tone-mark row shows when any of its real class entries is in scope.
    /// Entries without a tone (๊ and ๋ on low and high class) are empty
    /// columns, not content, so they never qualify a row.
    func includes(_ mark: ToneMark) -> Bool {
        let entries = mark.classEntries.filter { $0.tone != nil }
        if let key = revealed[.toneMark], entries.contains(where: { $0.soundKey == key }) { return true }
        return entries.contains { includes(mark, className: $0.className) }
    }

    /// The row's existing forms the book has not introduced yet.
    func hiddenForms(of vowel: Vowel) -> Set<VowelFormVariant> {
        guard isActive, let map else { return [] }
        var hidden = Set(VowelFormVariant.all.filter { variant in
            guard vowel.form(variant) != nil else { return false }
            return !scope.includes(map.placement(of: vowel, duration: variant.duration, form: variant.form))
        })
        // A jump names a spelling, which can fill two slots (เกิ-). It needs an
        // exception only when none of them is visible, and then reveals just
        // one: the first in row order, the slot its flashcard is built from.
        if let target = revealed[.vowel] {
            let slots = VowelFormVariant.all.filter { vowel.form($0) == target }
            if let first = slots.first, slots.allSatisfy(hidden.contains) {
                hidden.remove(first)
            }
        }
        return hidden
    }

    /// Whether the row has a visible form (of `duration`, when the duration chip is set).
    func showsRow(_ vowel: Vowel, duration: VowelCard.VowelDuration? = nil) -> Bool {
        let hidden = hiddenForms(of: vowel)
        return VowelFormVariant.all.contains { variant in
            vowel.form(variant) != nil && !hidden.contains(variant)
                && (duration == nil || variant.duration == duration)
        }
    }

    /// Whether the flashcard for this written form is in scope: any of the row's
    /// slots with that form (เกิ- has two) is enough, matching the deck.
    func includesVowelForm(_ vowel: Vowel, text: String) -> Bool {
        guard isActive else { return true }
        let hidden = hiddenForms(of: vowel)
        return VowelFormVariant.all.contains { vowel.form($0) == text && !hidden.contains($0) }
    }

    /// Whether the Practice action for a Reference item opens a card in chapter scope.
    func includes(_ item: ReferenceItem, data: ThaiDataStore) -> Bool {
        guard isActive else { return true }
        switch item {
        case .consonant(let id):
            return data.consonants.first { $0.id == id }.map { includes($0) } ?? true
        case .vowel(let id, _, let text):
            return data.vowels.first { $0.id == id }.map { includesVowelForm($0, text: text) } ?? true
        case .toneMark(let id, let soundKey):
            guard let mark = data.toneMarks.first(where: { $0.id == id }),
                  let entry = mark.classEntries.first(where: { $0.soundKey == soundKey }) else { return true }
            return includes(mark, className: entry.className)
        case .toneRule(let id):
            return data.toneRules.first { $0.id == id }.map { includes($0) } ?? true
        case .cluster(let id):
            return data.clusters.first { $0.id == id }.map { includes($0) } ?? true
        }
    }
}

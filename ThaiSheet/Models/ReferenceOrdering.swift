//
//  ReferenceOrdering.swift
//  ThaiSheet
//

import Foundation

/// Deterministic SplitMix64 generator so `.shuffle` ordering is reproducible from a
/// stored seed (the same seed always yields the same order across renders/launches).
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// How the Reference tab orders its flat lists (Consonants, Vowels).
/// `original` keeps the curated JSON order; the raw value stays "default" so the
/// persisted string and UI label read "Default" (`default` is a Swift keyword).
enum ReferenceSortMode: String, Codable, CaseIterable {
    case original = "default"
    case leastLearned
    case shuffle
}

/// An element paired with its sort keys for `.leastLearned` ordering.
private struct ScoredElement<Element> {
    let element: Element
    let stage: Int
    let index: Int
}

/// Pure ordering logic for the Reference tab, kept free of SwiftUI and `LearningModel`
/// so it is directly unit-testable (the SRS stage is injected as a closure).
enum ReferenceOrdering {
    /// Orders already search/chip-filtered `items` according to `mode`.
    ///
    /// - Parameters:
    ///   - filtered: the items currently passing the search/chip filters.
    ///   - source: the full, unfiltered collection. Used so ordering stays stable as
    ///     filters change — the shuffle position map and least-learned tie-break are
    ///     both keyed off positions in `source`, not in `filtered`.
    ///   - mode: the active sort mode.
    ///   - seed: seed for `.shuffle`.
    ///   - stage: SRS stage of an element (lower == less learned).
    static func ordered<Element: Identifiable>(
        _ filtered: [Element],
        from source: [Element],
        mode: ReferenceSortMode,
        seed: UInt64,
        stage: (Element) -> Int
    ) -> [Element] where Element.ID == String {
        switch mode {
        case .original:
            return filtered

        case .shuffle:
            // Shuffle the full collection once, then order the filtered subset by each
            // row's position. Shuffling `filtered` directly would reorder surviving
            // rows whenever the filter set changed, even with the same seed.
            var rng = SeededRandomNumberGenerator(seed: seed)
            let shuffledIDs = source.map(\.id).shuffled(using: &rng)
            var position: [String: Int] = [:]
            for (index, id) in shuffledIDs.enumerated() { position[id] = index }
            return filtered.sorted { (position[$0.id] ?? 0) < (position[$1.id] ?? 0) }

        case .leastLearned:
            // Ascending by stage (new/weak first), tie-broken by position in `source`
            // for a stable, filter-independent order (Swift's sort isn't stable).
            var sourceIndex: [String: Int] = [:]
            for (index, element) in source.enumerated() { sourceIndex[element.id] = index }

            let scored: [ScoredElement<Element>] = filtered.map { element in
                ScoredElement(
                    element: element,
                    stage: stage(element),
                    index: sourceIndex[element.id] ?? 0
                )
            }
            let sorted = scored.sorted { lhs, rhs in
                lhs.stage != rhs.stage ? lhs.stage < rhs.stage : lhs.index < rhs.index
            }
            return sorted.map(\.element)
        }
    }

    /// Minimum SRS stage across a set of card ids — the row-level score for a vowel,
    /// whose forms map to separate cards (the weakest form determines the rank).
    /// Empty input returns the `.new` raw value (0).
    static func minimumStage(for ids: [String], stage: (String) -> Int) -> Int {
        ids.map(stage).min() ?? 0
    }
}

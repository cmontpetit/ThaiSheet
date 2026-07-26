//
//  ReferenceOrderingTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

final class ReferenceOrderingTests: XCTestCase {

    private struct Item: Identifiable, Equatable {
        let id: String
    }

    private func items(_ ids: [String]) -> [Item] { ids.map(Item.init) }
    private func ids(_ items: [Item]) -> [String] { items.map(\.id) }

    // MARK: - Seeded RNG

    func test_seededRNG_sameSeed_sameSequence() {
        var a = SeededRandomNumberGenerator(seed: 99)
        var b = SeededRandomNumberGenerator(seed: 99)
        let seqA = (0..<10).map { _ in a.next() }
        let seqB = (0..<10).map { _ in b.next() }
        XCTAssertEqual(seqA, seqB)
    }

    // MARK: - .original

    func test_original_returnsFilteredUnchanged() {
        let source = items(["a", "b", "c", "d"])
        let filtered = items(["c", "a"]) // arbitrary filtered order
        let result = ReferenceOrdering.ordered(
            filtered, from: source, mode: .original, seed: 0
        ) { _ in 0 }
        XCTAssertEqual(ids(result), ["c", "a"])
    }

    // MARK: - .shuffle

    func test_shuffle_sameSeed_sameOrder() {
        let source = items(["a", "b", "c", "d", "e", "f", "g", "h"])
        let first = ReferenceOrdering.ordered(source, from: source, mode: .shuffle, seed: 777) { _ in 0 }
        let second = ReferenceOrdering.ordered(source, from: source, mode: .shuffle, seed: 777) { _ in 0 }
        XCTAssertEqual(ids(first), ids(second))
    }

    func test_shuffle_differentSeeds_differentOrder() {
        // Two fixed seeds whose resulting orders are known to differ for this fixture,
        // so the assertion is deterministic rather than probabilistic.
        let source = items(["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"])
        let orderA = ids(ReferenceOrdering.ordered(source, from: source, mode: .shuffle, seed: 1) { _ in 0 })
        let orderB = ids(ReferenceOrdering.ordered(source, from: source, mode: .shuffle, seed: 2) { _ in 0 })
        XCTAssertNotEqual(orderA, orderB)
    }

    func test_shuffle_isFilterInvariant() {
        let source = items(["a", "b", "c", "d", "e", "f"])
        let seed: UInt64 = 42
        let fullOrder = ids(ReferenceOrdering.ordered(source, from: source, mode: .shuffle, seed: seed) { _ in 0 })

        // Order a filtered subset (deliberately passed in a different order than source).
        let keep: Set<String> = ["b", "d", "f"]
        let subset = source.filter { keep.contains($0.id) }.reversed().map { $0 }
        let subOrder = ids(ReferenceOrdering.ordered(subset, from: source, mode: .shuffle, seed: seed) { _ in 0 })

        // Each surviving row keeps its relative position from the full shuffle.
        XCTAssertEqual(subOrder, fullOrder.filter { keep.contains($0) })
    }

    // MARK: - .leastLearned

    func test_leastLearned_ascendingByStage_stableOnTies() {
        let source = items(["a", "b", "c", "d"])
        let stages = ["a": 2, "b": 0, "c": 0, "d": 5]
        let result = ReferenceOrdering.ordered(
            source, from: source, mode: .leastLearned, seed: 0
        ) { stages[$0.id] ?? 0 }
        // stage 0 (b, c in source order) → stage 2 (a) → stage 5 (d)
        XCTAssertEqual(ids(result), ["b", "c", "a", "d"])
    }

    func test_leastLearned_tieBreakUsesSourceOrder_notFilteredOrder() {
        let source = items(["a", "b", "c", "d"])
        // All equal stage; pass filtered in reverse to prove source order wins the tie.
        let filtered = items(["d", "b"])
        let result = ReferenceOrdering.ordered(
            filtered, from: source, mode: .leastLearned, seed: 0
        ) { _ in 3 }
        XCTAssertEqual(ids(result), ["b", "d"])
    }

    // MARK: - minimumStage

    func test_minimumStage_returnsMinimumAcrossIds() {
        let stages = ["x": 3, "y": 1, "z": 5]
        let min = ReferenceOrdering.minimumStage(for: ["x", "y", "z"]) { stages[$0] ?? 0 }
        XCTAssertEqual(min, 1)
    }

    func test_minimumStage_emptyIds_returnsZero() {
        let min = ReferenceOrdering.minimumStage(for: []) { _ in 99 }
        XCTAssertEqual(min, 0)
    }
}

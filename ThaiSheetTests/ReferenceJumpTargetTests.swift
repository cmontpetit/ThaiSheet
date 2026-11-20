//
//  ReferenceJumpTargetTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

final class ReferenceJumpTargetTests: XCTestCase {
    private let data = ThaiDataStore()

    // MARK: - Target keys

    func testEmptyHighlightTargetsNothing() {
        let target = ReferenceJumpTarget(highlighted: [:])
        XCTAssertFalse(data.consonants.contains(where: target.contains))
        XCTAssertFalse(data.vowels.contains(where: target.contains))
        XCTAssertFalse(data.toneMarks.contains(where: target.contains))
        XCTAssertFalse(data.toneRules.contains(where: target.contains))
        XCTAssertFalse(data.clusters.contains(where: target.contains))
    }

    func testConsonantTargetMatchesByCharacter() {
        let target = ReferenceJumpTarget(highlighted: [.consonant: "ก"])
        XCTAssertEqual(data.consonants.filter(target.contains).map(\.character), ["ก"])
        // Other sections are untouched by a consonant jump
        XCTAssertFalse(data.clusters.contains(where: target.contains))
        XCTAssertFalse(data.vowels.contains(where: target.contains))
    }

    func testVowelTargetMatchesRowContainingForm() {
        let target = ReferenceJumpTarget(highlighted: [.vowel: "กะ"])
        XCTAssertEqual(data.vowels.filter(target.contains).map(\.id), ["a"])
    }

    func testToneMarkTargetMatchesRowBySoundKey() {
        // ค่า is the low-class entry of the mai ek row
        let target = ReferenceJumpTarget(highlighted: [.toneMark: "ค่า"])
        XCTAssertEqual(data.toneMarks.filter(target.contains).map(\.mark), ["่"])
        // The bare mark is not a sound key
        let markOnly = ReferenceJumpTarget(highlighted: [.toneMark: "่"])
        XCTAssertFalse(data.toneMarks.contains(where: markOnly.contains))
    }

    func testToneRuleTargetMatchesById() throws {
        let rule = try XCTUnwrap(data.toneRules.last)
        let target = ReferenceJumpTarget(highlighted: [.toneRule: rule.id])
        XCTAssertEqual(data.toneRules.filter(target.contains).map(\.id), [rule.id])
    }

    func testClusterTargetMatchesById() {
        let target = ReferenceJumpTarget(highlighted: [.cluster: "กร:initial"])
        XCTAssertEqual(data.clusters.filter(target.contains).map(\.id), ["กร:initial"])
    }

    // MARK: - Search results

    /// The reported bug: a saved "ia" search hid the consonant a flashcard's
    /// "View in Reference" asked for.
    func testSavedSearchKeepsJumpTargetBesideMatches() {
        let matchesIA: (Consonant) -> Bool = {
            $0.initialSound.matchesRomanized("ia") || $0.finalSound.matchesRomanized("ia")
        }
        let matches = data.consonants.filter(matchesIA)
        XCTAssertFalse(matches.contains { $0.character == "ก" }, "precondition: the query hides ก")

        let target = ReferenceJumpTarget(highlighted: [.consonant: "ก"])
        let results = ReferenceJumpTarget.searchResults(
            data.consonants, target: target.contains, matching: matchesIA)

        XCTAssertEqual(results.count, matches.count + 1, "only the target is added")
        XCTAssertTrue(results.contains { $0.character == "ก" })
        // Data order is kept
        let order = data.consonants.map(\.character)
        XCTAssertEqual(results.map(\.character), order.filter { c in results.contains { $0.character == c } })
    }

    func testTargetThatAlreadyMatchesIsNotDuplicated() {
        let target = ReferenceJumpTarget(highlighted: [.cluster: "กร:initial"])
        let results = ReferenceJumpTarget.searchResults(
            data.clusters, target: target.contains, matching: { $0.id.hasPrefix("ก") })
        XCTAssertEqual(results.filter { $0.id == "กร:initial" }.count, 1)
        XCTAssertEqual(results.map(\.id), data.clusters.filter { $0.id.hasPrefix("ก") }.map(\.id))
    }

    func testNoTargetLeavesSearchResultsUnchanged() {
        let target = ReferenceJumpTarget(highlighted: [:])
        let results = ReferenceJumpTarget.searchResults(
            data.toneRules, target: target.contains, matching: { $0.tone == "High" })
        XCTAssertEqual(results.map(\.id), data.toneRules.filter { $0.tone == "High" }.map(\.id))
    }
}

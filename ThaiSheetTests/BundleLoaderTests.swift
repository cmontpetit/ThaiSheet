//
//  BundleLoaderTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

final class BundleLoaderTests: XCTestCase {

    // MARK: - Consonant Loading

    func test_consonantLoadAll_returns44Consonants() {
        let consonants = Consonant.loadAll()
        XCTAssertEqual(consonants.count, 44, "Thai alphabet has exactly 44 consonants")
    }

    func test_consonantLoadAll_firstConsonantIsKhoKhwai() {
        let consonants = Consonant.loadAll()
        XCTAssertFalse(consonants.isEmpty)
        // The data file starts with ค (kho khwai)
        XCTAssertEqual(consonants[0].character, "ค")
        XCTAssertEqual(consonants[0].consonantClass, .low)
    }

    func test_consonantLoadAll_containsKoKai() {
        let consonants = Consonant.loadAll()
        let koKai = consonants.first(where: { $0.character == "ก" })
        XCTAssertNotNil(koKai, "ก (ko kai) should be in the consonant list")
        XCTAssertEqual(koKai?.consonantClass, .mid)
        XCTAssertEqual(koKai?.usage, .common)
    }

    func test_consonantLoadAll_hasAllThreeClasses() {
        let consonants = Consonant.loadAll()
        let classes = Set(consonants.map(\.consonantClass))
        XCTAssertTrue(classes.contains(.high))
        XCTAssertTrue(classes.contains(.mid))
        XCTAssertTrue(classes.contains(.low))
    }

    func test_consonantLoadAll_hasVariousUsages() {
        let consonants = Consonant.loadAll()
        let usages = Set(consonants.map(\.usage))
        XCTAssertTrue(usages.contains(.common), "Should have common consonants")
        XCTAssertTrue(usages.contains(.uncommon) || usages.contains(.rare) || usages.contains(.ancient),
                       "Should have at least some non-common consonants")
    }

    func test_consonantLoadAll_allHaveSounds() {
        let consonants = Consonant.loadAll()
        for consonant in consonants {
            XCTAssertFalse(consonant.initialSound.isEmpty,
                           "\(consonant.character) should have an initial sound")
            XCTAssertFalse(consonant.finalSound.isEmpty,
                           "\(consonant.character) should have a final sound")
        }
    }

    func test_consonantLoadAll_allHaveNames() {
        let consonants = Consonant.loadAll()
        for consonant in consonants {
            XCTAssertFalse(consonant.name.isEmpty,
                           "\(consonant.character) should have a name")
            XCTAssertFalse(consonant.character.isEmpty,
                           "All consonants should have a character")
        }
    }

    func test_consonantLoadAll_allHaveUniqueCharacters() {
        let consonants = Consonant.loadAll()
        let characters = consonants.map(\.character)
        let uniqueCharacters = Set(characters)
        XCTAssertEqual(characters.count, uniqueCharacters.count,
                       "All consonant characters should be unique")
    }

    // MARK: - Vowel Loading

    func test_vowelLoadAll_returnsNonEmptyArray() {
        let vowels = Vowel.loadAll()
        XCTAssertFalse(vowels.isEmpty)
    }

    func test_vowelLoadAll_returnsAtLeast20() {
        let vowels = Vowel.loadAll()
        XCTAssertGreaterThanOrEqual(vowels.count, 20,
                                    "Should have at least 20 vowels")
    }

    func test_vowelLoadAll_returns33Vowels() {
        let vowels = Vowel.loadAll()
        XCTAssertEqual(vowels.count, 33)
    }

    func test_vowelLoadAll_idsAreUnique() {
        // Duplicate ids break SwiftUI List identity (rows render multiple times)
        let ids = Vowel.loadAll().map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Vowel ids must be unique")
    }

    func test_vowelLoadAll_allHaveSounds() {
        let vowels = Vowel.loadAll()
        for vowel in vowels {
            XCTAssertFalse(vowel.sound.isEmpty,
                           "Vowel should have a sound")
        }
    }

    func test_vowelLoadAll_allHaveAtLeastOneForm() {
        let vowels = Vowel.loadAll()
        for vowel in vowels {
            let hasSomeForm = vowel.short.closed != nil || vowel.short.open != nil ||
                              vowel.long.closed != nil || vowel.long.open != nil
            XCTAssertTrue(hasSomeForm,
                          "Vowel with sound '\(vowel.sound)' should have at least one form")
        }
    }

    // MARK: - ToneMark Loading

    func test_toneMarkLoadAll_returnsNonEmptyArray() {
        let toneMarks = ToneMark.loadAll()
        XCTAssertFalse(toneMarks.isEmpty)
    }

    func test_toneMarkLoadAll_returns5ToneMarks() {
        let toneMarks = ToneMark.loadAll()
        XCTAssertEqual(toneMarks.count, 5, "Should have 5 tone marks (including no-mark)")
    }

    func test_toneMarkLoadAll_firstIsNoMark() {
        let toneMarks = ToneMark.loadAll()
        XCTAssertEqual(toneMarks[0].mark, "", "First tone mark should be empty (no mark)")
        XCTAssertEqual(toneMarks[0].onLowConsonant, "Mid")
        XCTAssertEqual(toneMarks[0].onMidHighConsonant, "Mid")
    }

    func test_toneMarkLoadAll_allHaveToneInfo() {
        let toneMarks = ToneMark.loadAll()
        for toneMark in toneMarks {
            XCTAssertFalse(toneMark.onLowConsonant.isEmpty,
                           "Tone mark '\(toneMark.mark)' should have low consonant tone")
            XCTAssertFalse(toneMark.onMidHighConsonant.isEmpty,
                           "Tone mark '\(toneMark.mark)' should have mid/high consonant tone")
        }
    }

    // MARK: - ToneRule Loading

    func test_toneRuleLoadAll_returnsNonEmptyArray() {
        let toneRules = ToneRule.loadAll()
        XCTAssertFalse(toneRules.isEmpty)
    }

    func test_toneRuleLoadAll_returns7Rules() {
        let toneRules = ToneRule.loadAll()
        XCTAssertEqual(toneRules.count, 7, "Standard Thai tone table has 7 rules")
    }

    func test_toneRuleLoadAll_hasAllConsonantClasses() {
        let toneRules = ToneRule.loadAll()
        let classes = Set(toneRules.map(\.initialConsonant))
        XCTAssertTrue(classes.contains("High"), "Should have High class rules")
        XCTAssertTrue(classes.contains("Mid"), "Should have Mid class rules")
        XCTAssertTrue(classes.contains("Low"), "Should have Low class rules")
    }

    func test_toneRuleLoadAll_allHaveTones() {
        let toneRules = ToneRule.loadAll()
        for rule in toneRules {
            XCTAssertFalse(rule.tone.isEmpty,
                           "Rule \(rule.id) should have a tone")
        }
    }

    func test_toneRuleLoadAll_allHaveVowelDurationAndEnd() {
        let toneRules = ToneRule.loadAll()
        for rule in toneRules {
            XCTAssertFalse(rule.vowelDuration.isEmpty,
                           "Rule \(rule.id) should have a vowel duration")
            XCTAssertFalse(rule.end.isEmpty,
                           "Rule \(rule.id) should have an end type")
        }
    }

    // MARK: - Cluster Loading

    func test_clusterLoadAll_returnsNonEmptyArray() {
        let clusters = Cluster.loadAll()
        XCTAssertFalse(clusters.isEmpty)
    }

    func test_clusterLoadAll_returns30Clusters() {
        let clusters = Cluster.loadAll()
        XCTAssertEqual(clusters.count, 30)
    }

    func test_clusterLoadAll_hasAllTypes() {
        let clusters = Cluster.loadAll()
        let types = Set(clusters.map(\.type))
        XCTAssertTrue(types.contains(.smooth), "Should have smooth clusters")
        XCTAssertTrue(types.contains(.silent), "Should have silent clusters")
        XCTAssertTrue(types.contains(.irregular), "Should have irregular clusters")
    }

    func test_clusterLoadAll_allHaveClusterString() {
        let clusters = Cluster.loadAll()
        for cluster in clusters {
            XCTAssertFalse(cluster.cluster.isEmpty,
                           "Cluster should have a cluster string")
        }
    }

    func test_clusterLoadAll_allHaveUniqueIds() {
        let clusters = Cluster.loadAll()
        let ids = clusters.map(\.id)
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count,
                       "All cluster IDs should be unique")
    }

    func test_clusterGrouped_returnsGroupedByType() {
        let clusters = Cluster.loadAll()
        let grouped = Cluster.grouped(clusters)
        XCTAssertFalse(grouped.isEmpty)

        let groupTypes = grouped.map(\.type)
        // All types should be present
        XCTAssertTrue(groupTypes.contains(.smooth))
        XCTAssertTrue(groupTypes.contains(.silent))
        XCTAssertTrue(groupTypes.contains(.irregular))

        // Total count across groups should equal total clusters
        let totalGrouped = grouped.reduce(0) { $0 + $1.clusters.count }
        XCTAssertEqual(totalGrouped, clusters.count)
    }

    // MARK: - BundleLoader with invalid resource

    func test_bundleLoader_invalidResource_returnsEmptyArray() {
        let result = BundleLoader.load("nonexistent-file", as: ConsonantsData.self, keyPath: \.consonants)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Localized Notes

    func test_clusterNotes_allHaveFrenchTranslations() {
        let notes = Cluster.loadAll().compactMap(\.note)
        XCTAssertFalse(notes.isEmpty, "Some clusters should carry notes")
        for note in notes {
            XCTAssertFalse(note.en.isEmpty)
            XCTAssertFalse(note.fr?.isEmpty ?? true,
                           "Cluster note missing French: \(note.en)")
        }
    }

    func test_toneSampleNotes_allHaveFrenchTranslations() {
        let notes = ToneRule.loadAll().flatMap { $0.samples ?? [] }.compactMap(\.note)
        XCTAssertFalse(notes.isEmpty, "Some tone samples should carry notes")
        for note in notes {
            XCTAssertFalse(note.en.isEmpty)
            XCTAssertFalse(note.fr?.isEmpty ?? true,
                           "Tone sample note missing French: \(note.en)")
        }
    }

    func test_vowelNotes_frenchMirrorsEnglishKeys() {
        let noted = Vowel.loadAll().compactMap(\.notes)
        XCTAssertFalse(noted.isEmpty, "Some vowels should carry notes")
        for notes in noted {
            guard let fr = notes.fr else {
                XCTFail("Vowel notes missing French block")
                continue
            }
            for key: KeyPath<VowelNotes, String?> in [\.short_closed, \.short_open, \.long_closed, \.long_open] {
                XCTAssertEqual(notes.en[keyPath: key] == nil, fr[keyPath: key] == nil,
                               "French vowel notes must mirror the English keys")
            }
        }
    }
}

//
//  ReferenceContentFilterTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

/// The Content toggles as Reference applies them.
@MainActor
final class ReferenceContentFilterTests: XCTestCase {

    private var data: ThaiDataStore!

    override func setUp() {
        super.setUp()
        data = ThaiDataStore()
    }

    override func tearDown() {
        data = nil
        super.tearDown()
    }

    private func consonant(_ character: String) throws -> Consonant {
        try XCTUnwrap(data.consonants.first { $0.character == character })
    }

    private func vowel(_ id: String) throws -> Vowel {
        try XCTUnwrap(data.vowels.first { $0.id == id })
    }

    func test_default_showsEverything() throws {
        let filter = ReferenceContentFilter(showsUncommonConsonants: true, showsUncommonVowels: true)
        XCTAssertTrue(data.consonants.allSatisfy { filter.includes($0) })
        XCTAssertTrue(data.vowels.allSatisfy { filter.includes($0) })
    }

    func test_uncommonConsonantsOff_hidesOnlyNonCommon() throws {
        let filter = ReferenceContentFilter(showsUncommonConsonants: false, showsUncommonVowels: true)
        XCTAssertFalse(filter.includes(try consonant("ฃ")))
        XCTAssertTrue(filter.includes(try consonant("ก")))
        XCTAssertEqual(data.consonants.filter { filter.includes($0) }.count,
                       data.consonants.filter { $0.usage == .common }.count)
    }

    func test_uncommonVowelsOff_hidesRareRows() throws {
        let filter = ReferenceContentFilter(showsUncommonConsonants: true, showsUncommonVowels: false)
        XCTAssertFalse(filter.includes(try vowel("rue")))
        XCTAssertTrue(filter.includes(try vowel("a")))
    }

    /// Same setting as the flashcard deck: a consonant hidden in Reference is
    /// also left out of the cards.
    func test_matchesFlashcardSetting() throws {
        let suiteName = "ReferenceContentFilterTests_\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let settings = FlashcardSettings(defaults: defaults)
        settings.uncommonConsonants = false
        let filter = ReferenceContentFilter(settings: settings)
        for c in data.consonants {
            XCTAssertEqual(filter.includes(c), settings.isConsonantEnabled(c), c.character)
        }
    }

    func test_jumpTarget_staysVisible() throws {
        let filter = ReferenceContentFilter(showsUncommonConsonants: false, showsUncommonVowels: false)
        XCTAssertTrue(filter.revealing([.consonant: "ฃ"]).includes(try consonant("ฃ")))
        XCTAssertTrue(filter.revealing([.vowel: "ฤ"]).includes(try vowel("rue")))
        XCTAssertFalse(filter.revealing([.consonant: "ฃ"]).includes(try consonant("ฅ")), "only the target")
    }

    func test_all_isWhatSearchUses() throws {
        XCTAssertTrue(ReferenceContentFilter.all.includes(try consonant("ฃ")))
        XCTAssertTrue(ReferenceContentFilter.all.includes(try vowel("lue")))
    }
}

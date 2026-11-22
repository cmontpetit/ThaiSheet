//
//  DeckSyncTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

/// Keeps short-lived models alive for the whole run (see the Swift 6.2
/// deinit note in CLAUDE.md "Testing Gotchas").
private enum Retained {
    nonisolated(unsafe) static var objects: [AnyObject] = []
}

/// `FlashcardManager` applies one deck snapshot per logical settings change.
@MainActor
final class DeckSyncTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settings: FlashcardSettings!
    private var manager: FlashcardManager!

    override func setUp() {
        super.setUp()
        suiteName = "DeckSyncTests_\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settings = FlashcardSettings(defaults: defaults)
        let data = ThaiDataStore()
        let learningModel = LearningModel(store: defaults)
        manager = FlashcardManager(settings: settings, learningModel: learningModel, data: data)
        Retained.objects.append(contentsOf: [data, settings, learningModel, manager] as [AnyObject])
    }

    override func tearDown() {
        manager = nil
        settings = nil
        defaults = nil
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        suiteName = nil
        super.tearDown()
    }

    private func consonant(_ character: String) throws -> FlashcardItem {
        let consonant = try XCTUnwrap(manager.data.consonants.first { $0.character == character })
        return .consonant(consonant, includesName: settings.consonantNames)
    }

    /// Every deck-dependent read the UI makes.
    private func readEverything() {
        _ = manager.filteredCards
        _ = manager.allCards
        _ = manager.hasActiveFilters
        _ = manager.currentCard
        _ = manager.currentIndex
        for card in manager.allCards {
            _ = manager.isPartialTesting(card)
        }
    }

    /// The card IDs Sequential navigation visits in one full lap.
    private func sequentialLap() -> [String] {
        manager.filteredCards.indices.compactMap { _ in
            defer { manager.nextCard() }
            return manager.currentCard?.id
        }
    }

    // MARK: - One refresh per logical change

    func test_bulkChange_appliesOneRefreshAndOneAttempt() {
        let fullDeck = manager.filteredCards.map(\.id)
        let attempt = manager.attempt

        settings.deselectAll()
        XCTAssertEqual(manager.filteredCards.map(\.id), fullDeck, "Reading never applies settings")
        XCTAssertTrue(manager.syncDeck())
        XCTAssertFalse(manager.syncDeck(), "The second sync finds nothing to apply")
        XCTAssertTrue(manager.filteredCards.isEmpty)
        XCTAssertEqual(manager.attempt, attempt + 1)

        settings.selectAll()
        XCTAssertTrue(manager.syncDeck())
        XCTAssertFalse(manager.syncDeck())
        XCTAssertEqual(manager.filteredCards.map(\.id), fullDeck)
        XCTAssertEqual(manager.attempt, attempt + 2)
    }

    func test_parentToggle_setsChildrenInTheSameChange() {
        let attempt = manager.attempt
        settings.setCategory(\.consonantsEnabled, to: false)
        XCTAssertFalse(settings.highConsonants || settings.midConsonants || settings.lowConsonants)
        XCTAssertTrue(manager.syncDeck())
        XCTAssertFalse(manager.syncDeck())
        XCTAssertFalse(manager.filteredCards.contains { $0.type == .consonant })
        XCTAssertEqual(manager.attempt, attempt + 1)

        settings.setCategory(\.consonantsEnabled, to: true)
        XCTAssertTrue(settings.highConsonants && settings.midConsonants && settings.lowConsonants)
        XCTAssertTrue(manager.syncDeck())
        XCTAssertEqual(manager.attempt, attempt + 2)
    }

    func test_studyContentToggle_appliesOnce() {
        let attempt = manager.attempt
        settings.setUncommonLetters(false)
        XCTAssertTrue(manager.syncDeck())
        XCTAssertFalse(manager.syncDeck())
        XCTAssertEqual(manager.attempt, attempt + 1)
    }

    func test_reads_haveNoSideEffects() {
        let attempt = manager.attempt
        let card = manager.currentCard?.id
        readEverything()
        settings.highConsonants = false
        readEverything()
        XCTAssertEqual(manager.attempt, attempt)
        XCTAssertEqual(manager.currentCard?.id, card)
        XCTAssertTrue(manager.filteredCards.contains { $0.id == "consonant-ข" }, "Not applied until synced")
    }

    func test_restartKeepingTheSameCard_stillStartsANewAttempt() {
        let card = manager.currentCard?.id
        let attempt = manager.attempt
        settings.uncommonVowels = false
        manager.syncDeck()
        XCTAssertEqual(manager.currentCard?.id, card)
        XCTAssertEqual(manager.attempt, attempt + 1)
    }

    func test_selectionModeIsNotADeckSetting() {
        let attempt = manager.attempt
        settings.selectionMode = .smart
        XCTAssertFalse(manager.syncDeck())
        XCTAssertEqual(manager.attempt, attempt)
    }

    // MARK: - Changes made away from Flashcards

    /// Flashcards has never been shown: Practice from Reference still uses the new chapter.
    func test_chapterChangeBeforeFlashcardsShown_isReflected() {
        settings.bookProgress = .day1
        manager.practice(.consonant("ง"))

        XCTAssertEqual(manager.currentCard?.id, "consonant-ง")
        XCTAssertEqual(manager.currentIndex, 0)
        let consonants = Set(manager.filteredCards.filter { $0.type == .consonant }.map(\.id))
        XCTAssertEqual(consonants, Set(["ง", "ม", "น", "ร", "ล", "ย", "ว"].map { "consonant-\($0)" }))
    }

    func test_externalReload_isReflected() {
        let attempt = manager.attempt
        defaults.set(BookChapter.day1.rawValue, forKey: "fc_bookProgress")
        defaults.set(false, forKey: "fc_consonantNames")
        manager.reloadFromSyncedStore()

        XCTAssertEqual(settings.bookProgress, .day1)
        let consonants = Set(manager.filteredCards.filter { $0.type == .consonant }.map(\.id))
        XCTAssertEqual(consonants, Set(["ง", "ม", "น", "ร", "ล", "ย", "ว"].map { "consonantSound-\($0)" }))
        XCTAssertEqual(manager.attempt, attempt + 1, "Two changed settings, one restart")
    }

    /// Smart selection after a sync picks from the reloaded progress: the only
    /// due card wins over new ones.
    func test_syncReload_smartSelectionUsesReloadedProgress() throws {
        settings.selectionMode = .smart
        settings.vowelsEnabled = false
        settings.tonesEnabled = false
        settings.clusters = false
        manager.syncDeck()
        let due = try consonant("ม")

        // Another device reviewed ม two days ago, so it is due now.
        let remote = LearningModel(store: defaults)
        Retained.objects.append(remote)
        let twoDaysAgo = Date().addingTimeInterval(-2 * 86_400)
        remote.clock = { twoDaysAgo }
        remote.recordResult(for: due, correct: true, fullTesting: true)
        defaults.set(false, forKey: "fc_highConsonants")

        manager.reloadFromSyncedStore()
        XCTAssertTrue(manager.learningModel.isDue(due))
        XCTAssertEqual(manager.currentCard?.id, due.id)
    }

    // MARK: - One snapshot for every consumer

    func test_afterChange_navigationCountAndCapAgree() throws {
        settings.midConsonants = false
        settings.lowConsonants = false

        // Not yet applied: everything still agrees on the old deck.
        XCTAssertEqual(sequentialLap(), manager.filteredCards.map(\.id))
        XCTAssertFalse(manager.isPartialTesting(try consonant("ข")))

        manager.syncDeck()
        let deck = manager.filteredCards.map(\.id)
        XCTAssertEqual(sequentialLap(), deck, "Sequential visits exactly the applied deck")
        XCTAssertTrue(manager.hasActiveFilters)
        XCTAssertTrue(deck.contains("consonant-ข"))
        XCTAssertFalse(deck.contains("consonant-ก"), "ก is mid class")
        XCTAssertTrue(manager.isPartialTesting(try consonant("ข")), "Only high class left: the class is given away")
    }

    // MARK: - DeckSettings coverage

    /// Synced settings that do not change the deck. Any other synced key must
    /// be part of `DeckSettings`, or the deck would miss its change.
    private static let nonDeckKeys: Set<String> = [
        "fc_selectionMode", "fc_useIntelligentSelection", "fc_recordedVoice", "fc_voiceOverrides",
        "fc_appLanguage", "fc_romanization",
    ]

    func test_deckSettings_coversEverySyncedDeckSetting() {
        for key in FlashcardSettings.syncedKeys where !Self.nonDeckKeys.contains(key) {
            let values: [Any] = key == "fc_bookProgress"
                ? [BookChapter.day3.rawValue, FlashcardSettings.bookProgressOff]
                : [true, false]
            let snapshots = values.map { value in
                defaults.set(value, forKey: key)
                settings.reload()
                return settings.deckSettings
            }
            XCTAssertNotEqual(snapshots[0], snapshots[1], "\(key) does not reach DeckSettings")
        }
    }
}

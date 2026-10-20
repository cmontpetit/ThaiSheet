//
//  ConsonantModeTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

/// Switching consonant cards between quizzing the name and skipping it.
@MainActor
final class ConsonantModeTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settings: FlashcardSettings!
    private var manager: FlashcardManager!

    override func setUp() {
        super.setUp()
        suiteName = "ConsonantModeTests_\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settings = FlashcardSettings(defaults: defaults)
        let data = ThaiDataStore()
        let manager = FlashcardManager(
            settings: settings,
            learningModel: LearningModel(store: defaults),
            data: data
        )
        self.manager = manager
        Retained.objects.append(contentsOf: [data, manager] as [AnyObject])
    }

    override func tearDown() {
        manager = nil
        settings = nil
        defaults = nil
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Deck

    func test_switchingMode_changesDeckIDs() {
        let namedIDs = manager.filteredCards.filter { $0.type == .consonant }.map(\.id)
        XCTAssertFalse(namedIDs.isEmpty)
        XCTAssertTrue(namedIDs.allSatisfy { $0.hasPrefix("consonant-") })

        settings.consonantNames = false
        manager.applyConsonantMode()

        let soundIDs = manager.filteredCards.filter { $0.type == .consonant }.map(\.id)
        XCTAssertEqual(soundIDs.count, namedIDs.count)
        XCTAssertTrue(soundIDs.allSatisfy { $0.hasPrefix("consonantSound-") })
        XCTAssertEqual(manager.currentCard?.id, manager.filteredCards.first?.id)
    }

    // MARK: - Reference override

    func test_switchingMode_rebuildsReferenceOverrideInNewMode() {
        settings.highConsonants = false
        manager.resetToStart()
        manager.jumpToConsonant("ข")
        XCTAssertEqual(manager.currentCard?.id, "consonant-ข",
                       "A filtered-out consonant opened from Reference shows as an override")

        settings.consonantNames = false
        manager.applyConsonantMode()

        XCTAssertEqual(manager.currentCard?.id, "consonantSound-ข",
                       "The override stays on the same letter but records progress in the new mode")
    }

    // MARK: - iCloud

    func test_syncedModeChange_reloadThenApply_movesToNewIDs() {
        // A synced store change lands in the backing store, then the
        // .syncedStoreDidChange handler reloads settings; ContentView's
        // onChange(of: consonantNames) then calls applyConsonantMode().
        defaults.set(false, forKey: "fc_consonantNames")
        settings.reload()
        XCTAssertFalse(settings.consonantNames)

        manager.applyConsonantMode()

        XCTAssertEqual(manager.currentCard?.id, manager.filteredCards.first?.id)
        XCTAssertTrue(manager.currentCard?.id.hasPrefix("consonantSound-") ?? false)
        XCTAssertTrue(manager.filteredCards.filter { $0.type == .consonant }
            .allSatisfy { $0.id.hasPrefix("consonantSound-") })
    }

    // MARK: - Reference detail sheet

    func test_detailSheet_showsActiveModeStage() throws {
        let consonant = try XCTUnwrap(manager.data.consonants.first { $0.character == "ก" })
        let named = FlashcardItem.consonant(consonant, includesName: true)
        let sound = FlashcardItem.consonant(consonant, includesName: false)
        manager.learningModel.recordResult(for: named, correct: true, fullTesting: true)
        manager.learningModel.recordResult(for: sound, correct: true, fullTesting: true)
        manager.learningModel.recordResult(for: sound, correct: true, fullTesting: true)

        func shownStage() -> SRSStage {
            manager.learningModel.getProgress(
                forId: ConsonantDetailSheet.progressID(for: consonant, settings: settings)
            ).srsStage
        }

        XCTAssertEqual(shownStage(), .learning1, "Names on: the sheet shows name-mode progress")
        settings.consonantNames = false
        XCTAssertEqual(shownStage(), .learning2, "Names off: the sheet shows name-free progress")
        XCTAssertEqual(ConsonantDetailSheet.progressID(for: consonant, settings: nil), "consonant-ก",
                       "Without settings in the environment, the sheet falls back to name mode")
    }

    // MARK: - Grading

    func test_hasError_ignoresMissingName() throws {
        let consonant = try XCTUnwrap(manager.data.consonants.first { $0.character == "ก" })
        var state = CardState()
        state.selectedClass = consonant.consonantClass
        state.selectedInitial = consonant.initialSound
        state.selectedFinal = consonant.finalSound

        XCTAssertFalse(state.hasError(for: consonant), "A card without the name step passes on three right answers")

        state.selectedFinal = "-wrong"
        XCTAssertTrue(state.hasError(for: consonant))
    }
}

/// Keeps short-lived @Observable instances alive for the test run, like the
/// fixtures in ProgressIDMigrationTests (see the deinit note in CLAUDE.md).
private enum Retained {
    static var objects: [AnyObject] = []
}

//
//  BookChapterTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

@MainActor
final class BookChapterMapTests: XCTestCase {

    private var data: ThaiDataStore!
    private var map: BookChapterMap!

    override func setUp() {
        super.setUp()
        data = ThaiDataStore()
        map = data.bookChapters
    }

    override func tearDown() {
        data = nil
        map = nil
        super.tearDown()
    }

    func test_bundledMap_loads() {
        XCTAssertNil(data.bookChaptersFailure)
        XCTAssertNotNil(map)
    }

    // MARK: - Every catalog item is classified, nothing extra

    func test_everyConsonantHasAnEntry() throws {
        let map = try XCTUnwrap(map)
        let ids = Set(data.consonants.map(\.id))
        XCTAssertEqual(ids.count, 44)
        XCTAssertEqual(Set(map.consonants.keys), ids)
    }

    func test_everyVowelSlotHasAnEntry() throws {
        let map = try XCTUnwrap(map)
        var slots: Set<String> = []
        for vowel in data.vowels {
            let forms: [(String?, VowelCard.VowelDuration, VowelCard.VowelFormType)] = [
                (vowel.short.closed, .short, .closed), (vowel.short.open, .short, .open),
                (vowel.long.closed, .long, .closed), (vowel.long.open, .long, .open),
            ]
            for (form, duration, formType) in forms where form != nil {
                slots.insert(BookChapterMap.vowelSlotKey(vowel, duration: duration, form: formType))
                XCTAssertNotNil(map.placement(of: vowel, duration: duration, form: formType),
                                "\(vowel.id) \(duration) \(formType)")
            }
        }
        XCTAssertEqual(slots.count, 72)
        XCTAssertEqual(Set(map.vowels.keys), slots)
    }

    func test_everyVowelCardHasAPlacementForItsSlot() throws {
        let map = try XCTUnwrap(map)
        for card in data.vowelCards {
            XCTAssertNotNil(map.placement(of: card.vowel, duration: card.duration, form: card.form), card.id)
        }
    }

    func test_everyClusterHasAnEntry() throws {
        let map = try XCTUnwrap(map)
        XCTAssertEqual(Set(map.clusters.keys), Set(data.clusters.map(\.id)))
    }

    func test_everyToneRuleSampleHasAnEntry() throws {
        let map = try XCTUnwrap(map)
        XCTAssertEqual(Set(map.toneRules.keys), Set(data.toneRuleCards.map { ToneRuleCard.key(rule: $0.rule, sample: $0.sample) }))
    }

    func test_everyToneMarkCardHasAnEntry() throws {
        let map = try XCTUnwrap(map)
        XCTAssertEqual(Set(map.toneMarks.keys), Set(data.toneMarkCards.map(\.id)))
    }

    // MARK: - Content checks from the A1 review

    /// The Intermission checklist (book p.59) lists exactly the 28 consonants of DAY 1–4.
    func test_intermissionBenchmark_28Consonants() throws {
        let map = try XCTUnwrap(map)
        let scope = BookScope(upTo: .day4, includesNotInBook: false)
        let inScope = Set(data.consonants.filter { scope.includes(map.placement(of: $0)) }.map(\.id))
        let expected = Set(["ง", "ม", "น", "ร", "ล", "ย", "ว",
                            "ค", "ท", "ช", "ซ", "พ", "ฟ", "ฮ",
                            "ก", "จ", "ด", "ต", "บ", "ป", "อ",
                            "ข", "ถ", "ฉ", "ส", "ผ", "ฝ", "ห"])
        XCTAssertEqual(inScope, expected)
    }

    /// Q1: every tone-rule sample takes DAY 5, even when its word uses a later letter.
    func test_toneRuleSamples_allDay5() throws {
        let map = try XCTUnwrap(map)
        XCTAssertFalse(map.toneRules.isEmpty)
        XCTAssertTrue(map.toneRules.values.allSatisfy { $0 == .chapter(.day5) })
    }

    func test_toneMarks_allDay6() throws {
        let map = try XCTUnwrap(map)
        XCTAssertEqual(map.toneMarks.count, 8)
        XCTAssertTrue(map.toneMarks.values.allSatisfy { $0 == .chapter(.day6) })
    }

    /// M2: เกิ- is taught as the closed form of long เ-อ only.
    func test_sharedForm_oeClosed() throws {
        let map = try XCTUnwrap(map)
        let oe = try XCTUnwrap(data.vowels.first { $0.id == "oe" })
        XCTAssertEqual(map.placement(of: oe, duration: .long, form: .closed), .chapter(.day5))
        XCTAssertEqual(map.placement(of: oe, duration: .short, form: .closed), .notInBook)
    }

    /// The chapter key is the Reference slot, not the progress key override.
    func test_vowelLookupUsesSlotKey_notProgressKey() throws {
        let map = try XCTUnwrap(map)
        let uay = try XCTUnwrap(data.vowels.first { $0.id == "uay" })
        XCTAssertEqual(uay.progressKey(for: .long, form: .closed), "uay:Short:Closed")
        XCTAssertEqual(BookChapterMap.vowelSlotKey(uay, duration: .long, form: .closed), "uay:Long:Closed")
        XCTAssertEqual(map.placement(of: uay, duration: .long, form: .closed), .chapter(.day5))
    }

    // MARK: - Decoding

    func test_decode_rejectsUnknownChapter() {
        let json = #"{"chapters": [], "consonants": {"ก": "day11"}, "vowels": {}, "clusters": {}, "toneRules": {}, "toneMarks": {}}"#
        XCTAssertThrowsError(try BookChapterMap.decode(Data(json.utf8)))
    }

    func test_decode_readsChaptersAndNotInBook() throws {
        let json = #"{"chapters": [], "consonants": {"ก": "day3", "ฃ": "notInBook"}, "vowels": {}, "clusters": {}, "toneRules": {}, "toneMarks": {}}"#
        let decoded = try BookChapterMap.decode(Data(json.utf8))
        XCTAssertEqual(decoded.consonants["ก"], .chapter(.day3))
        XCTAssertEqual(decoded.consonants["ฃ"], .notInBook)
    }
}

final class BookScopeTests: XCTestCase {

    func test_chaptersAreOrdered() {
        XCTAssertEqual(BookChapter.allCases.first, .day1)
        XCTAssertEqual(BookChapter.allCases.last, .lastDay)
        XCTAssertLessThan(BookChapter.day9, .lastDay)
        XCTAssertLessThan(BookChapter.day1, .day2)
    }

    func test_off_includesEverything() {
        let scope = BookScope(upTo: nil, includesNotInBook: false)
        XCTAssertFalse(scope.isActive)
        XCTAssertTrue(scope.includes(.chapter(.lastDay)))
        XCTAssertTrue(scope.includes(.notInBook))
        XCTAssertTrue(scope.includes(nil))
    }

    func test_active_isCumulative() {
        let scope = BookScope(upTo: .day5, includesNotInBook: false)
        XCTAssertTrue(scope.isActive)
        for chapter in BookChapter.allCases {
            XCTAssertEqual(scope.includes(.chapter(chapter)), chapter <= .day5, "\(chapter)")
        }
    }

    func test_active_notInBookFollowsToggle() {
        XCTAssertFalse(BookScope(upTo: .day1, includesNotInBook: false).includes(.notInBook))
        XCTAssertTrue(BookScope(upTo: .day1, includesNotInBook: true).includes(.notInBook))
    }

    func test_specificDays_includeOnlyThoseDays() {
        let scope = BookScope(selection: .days([.day2, .day4]), includesNotInBook: false)
        XCTAssertTrue(scope.isActive)
        for chapter in BookChapter.allCases {
            XCTAssertEqual(scope.includes(.chapter(chapter)), chapter == .day2 || chapter == .day4, "\(chapter)")
        }
        XCTAssertFalse(scope.includes(.notInBook))
        XCTAssertTrue(BookScope(selection: .days([.day2]), includesNotInBook: true).includes(.notInBook))
    }

    /// Day 5 alone is that day's material; Through Day 5 adds the earlier days.
    func test_day5Alone_vsThroughDay5() {
        let alone = BookScope(selection: .days([.day5]), includesNotInBook: false)
        let through = BookScope(selection: .through(.day5), includesNotInBook: false)
        XCTAssertTrue(alone.includes(.chapter(.day5)))
        XCTAssertFalse(alone.includes(.chapter(.day1)))
        XCTAssertTrue(through.includes(.chapter(.day1)))
        XCTAssertTrue(through.includes(.chapter(.day5)))
    }

    func test_selection_storageRoundTrip() {
        let values: [BookSelection] = [.off, .through(.day4), .days([.day2, .day4]), .days([.lastDay])]
        for value in values {
            XCTAssertEqual(BookSelection(storageValue: value.storageValue), value, value.storageValue)
        }
        XCTAssertEqual(BookSelection.days([.day4, .day2]).storageValue, "days:day2,day4", "book order")
        XCTAssertNil(BookSelection(storageValue: "days:"))
        XCTAssertNil(BookSelection(storageValue: "days:day2,day42"))
        XCTAssertNil(BookSelection(storageValue: "through:day42"))
        XCTAssertNil(BookSelection(storageValue: "weekly:day2"))
    }

    func test_selection_legacyProgressCoversTheSelection() {
        XCTAssertNil(BookSelection.off.legacyProgress)
        XCTAssertEqual(BookSelection.through(.day3).legacyProgress, .day3)
        XCTAssertEqual(BookSelection.days([.day2, .day7]).legacyProgress, .day7)
    }

    func test_active_missingEntryCountsAsNotInBook() {
        XCTAssertFalse(BookScope(upTo: .lastDay, includesNotInBook: false).includes(nil))
        XCTAssertTrue(BookScope(upTo: .lastDay, includesNotInBook: true).includes(nil))
    }
}

@MainActor
final class BookProgressSettingsTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settings: FlashcardSettings!

    override func setUp() {
        super.setUp()
        suiteName = "BookProgressSettingsTests_\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settings = FlashcardSettings(defaults: defaults)
    }

    override func tearDown() {
        settings = nil
        defaults = nil
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        suiteName = nil
        super.tearDown()
    }

    func test_defaults_offAndNotInBookHidden() {
        XCTAssertNil(settings.bookProgress)
        XCTAssertFalse(settings.showNotInBook)
        XCTAssertFalse(BookScope(settings: settings, map: nil).isActive)
    }

    func test_bookProgress_persistsRawValue() {
        settings.bookProgress = .day5
        XCTAssertEqual(defaults.string(forKey: "fc_bookProgress"), "day5")
    }

    /// Off is stored explicitly so turning the scope off syncs through iCloud.
    func test_bookProgress_offPersistsExplicitly() {
        settings.bookProgress = .day3
        settings.bookProgress = nil
        XCTAssertEqual(defaults.string(forKey: "fc_bookProgress"), FlashcardSettings.bookProgressOff)
    }

    func test_showNotInBook_persists() {
        settings.showNotInBook = true
        XCTAssertEqual(defaults.object(forKey: "fc_showNotInBook") as? Bool, true)
    }

    func test_reload_picksUpExternalChanges() {
        defaults.set("lastDay", forKey: "fc_bookProgress")
        defaults.set(true, forKey: "fc_showNotInBook")
        settings.reload()
        XCTAssertEqual(settings.bookProgress, .lastDay)
        XCTAssertTrue(settings.showNotInBook)
        XCTAssertEqual(BookScope(settings: settings, map: ThaiDataStore().bookChapters), BookScope(upTo: .lastDay, includesNotInBook: true))

        defaults.set(FlashcardSettings.bookProgressOff, forKey: "fc_bookProgress")
        settings.reload()
        XCTAssertNil(settings.bookProgress)
    }

    /// A map that failed to load disables the scope instead of hiding the catalog.
    func test_scope_missingMapIsOff() {
        settings.bookProgress = .day1
        let scope = BookScope(settings: settings, map: nil)
        XCTAssertFalse(scope.isActive)
        XCTAssertTrue(scope.includes(.chapter(.lastDay)))
        XCTAssertTrue(scope.includes(.notInBook))
    }

    func test_reload_unknownValueIsOff() {
        defaults.set("day42", forKey: "fc_bookProgress")
        settings.reload()
        XCTAssertNil(settings.bookProgress)
    }

    func test_reload_doesNotWriteBack() {
        settings.reload()
        XCTAssertNil(defaults.object(forKey: "fc_bookProgress"))
        XCTAssertNil(defaults.object(forKey: "fc_showNotInBook"))
    }

    func test_bookSelection_persistsWithLegacyProgress() {
        settings.bookSelection = .days([.day4, .day2])
        XCTAssertEqual(defaults.string(forKey: "fc_bookSelection"), "days:day2,day4")
        XCTAssertEqual(defaults.string(forKey: "fc_bookProgress"), "day4", "older builds read a superset")
        XCTAssertNil(settings.bookProgress, "specific days are not a cumulative chapter")

        settings.bookSelection = .through(.day3)
        XCTAssertEqual(defaults.string(forKey: "fc_bookSelection"), "through:day3")
        XCTAssertEqual(defaults.string(forKey: "fc_bookProgress"), "day3")

        settings.bookSelection = .off
        XCTAssertEqual(defaults.string(forKey: "fc_bookSelection"), "off")
        XCTAssertEqual(defaults.string(forKey: "fc_bookProgress"), FlashcardSettings.bookProgressOff)
    }

    /// A saved cumulative chapter from before day selection loads as Through.
    func test_legacyProgress_loadsAsThrough() {
        defaults.set("day4", forKey: "fc_bookProgress")
        let loaded = FlashcardSettings(defaults: defaults)
        XCTAssertEqual(loaded.bookSelection, .through(.day4))
        XCTAssertEqual(loaded.bookProgress, .day4)
    }

    func test_reload_picksUpExternalDaySelection() {
        defaults.set("days:day2,day5", forKey: "fc_bookSelection")
        settings.reload()
        XCTAssertEqual(settings.bookSelection, .days([.day2, .day5]))
    }

    /// One-way: once the selection key exists, a legacy value is ignored.
    func test_selectionKey_winsOverLegacyProgress() {
        settings.bookSelection = .days([.day2])
        defaults.set("lastDay", forKey: "fc_bookProgress")
        settings.reload()
        XCTAssertEqual(settings.bookSelection, .days([.day2]))
    }

    func test_reload_unreadableSelection_fallsBackToLegacyProgress() {
        defaults.set("days:day42", forKey: "fc_bookSelection")
        defaults.set("day3", forKey: "fc_bookProgress")
        settings.reload()
        XCTAssertEqual(settings.bookSelection, .through(.day3))
    }

    func test_syncedKeys_containBookScope() {
        XCTAssertTrue(FlashcardSettings.syncedKeys.contains("fc_bookSelection"))
        XCTAssertTrue(FlashcardSettings.syncedKeys.contains("fc_bookProgress"))
        XCTAssertTrue(FlashcardSettings.syncedKeys.contains("fc_showNotInBook"))
    }

    /// The Study Content button fills whenever the sheet hides something.
    func test_studyContentButton_activeWhenChapterSetOrUncommonHidden() {
        let map = ThaiDataStore().bookChapters
        XCTAssertFalse(StudyContentButton.isActive(settings: settings, map: map))
        settings.bookProgress = .day1
        XCTAssertTrue(StudyContentButton.isActive(settings: settings, map: map))
        settings.bookProgress = nil
        settings.uncommonVowels = false
        XCTAssertTrue(StudyContentButton.isActive(settings: settings, map: map), "either kind hidden counts")
        settings.setUncommonLetters(true)
        XCTAssertFalse(StudyContentButton.isActive(settings: settings, map: map))
    }

    func test_bulkActions_doNotTouchBookScope() {
        settings.bookProgress = .day2
        settings.showNotInBook = true
        settings.deselectAll()
        settings.selectAll()
        XCTAssertEqual(settings.bookProgress, .day2)
        XCTAssertTrue(settings.showNotInBook)
        XCTAssertTrue(settings.isAllSelected)
    }
}

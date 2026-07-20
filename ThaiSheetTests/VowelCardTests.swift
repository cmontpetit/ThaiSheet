//
//  VowelCardTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

final class VowelCardTests: XCTestCase {

    private var allVowels: [Vowel]!
    private var allCards: [VowelCard]!

    override func setUp() {
        super.setUp()
        allVowels = Vowel.loadAll()
        allCards = VowelCard.allCards(from: allVowels)
    }

    override func tearDown() {
        allVowels = nil
        allCards = nil
        super.tearDown()
    }

    // MARK: - allCards

    func test_allCards_producesNonEmptyList() {
        XCTAssertFalse(allCards.isEmpty, "allCards should produce a non-empty list from vowel data")
    }

    func test_allCards_producesReasonableCount() {
        // Each vowel can have up to 4 forms (short closed, short open, long closed, long open)
        // With 23 vowels, we should have a substantial number of cards
        XCTAssertGreaterThan(allCards.count, 20,
                             "Should have more than 20 vowel cards from 23 vowels")
        // But not more than 4 * 23 = 92 (theoretical max before dedup)
        XCTAssertLessThanOrEqual(allCards.count, 92,
                                  "Should not exceed 4 * vowel count")
    }

    // MARK: - No duplicates

    func test_allCards_noDuplicateDisplayValues() {
        let displays = allCards.map(\.display)
        let uniqueDisplays = Set(displays)
        XCTAssertEqual(displays.count, uniqueDisplays.count,
                       "All vowel card display values should be unique. Duplicates: \(findDuplicates(in: displays))")
    }

    func test_allCards_noDuplicateIds() {
        let ids = allCards.map(\.id)
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count,
                       "All vowel card IDs should be unique")
    }

    // MARK: - Duration assignments

    func test_allCards_hasBothDurations() {
        let durations = Set(allCards.map(\.duration))
        XCTAssertTrue(durations.contains(.short), "Should have short duration cards")
        XCTAssertTrue(durations.contains(.long), "Should have long duration cards")
    }

    func test_allCards_shortCardsHaveCorrectDuration() {
        let shortCards = allCards.filter { $0.duration == .short }
        XCTAssertFalse(shortCards.isEmpty)
        for card in shortCards {
            XCTAssertEqual(card.duration, .short)
        }
    }

    func test_allCards_longCardsHaveCorrectDuration() {
        let longCards = allCards.filter { $0.duration == .long }
        XCTAssertFalse(longCards.isEmpty)
        for card in longCards {
            XCTAssertEqual(card.duration, .long)
        }
    }

    // MARK: - Form assignments

    func test_allCards_hasBothForms() {
        let forms = Set(allCards.map(\.form))
        XCTAssertTrue(forms.contains(.closed), "Should have closed form cards")
        XCTAssertTrue(forms.contains(.open), "Should have open form cards")
    }

    func test_allCards_closedCardsHaveCorrectForm() {
        let closedCards = allCards.filter { $0.form == .closed }
        XCTAssertFalse(closedCards.isEmpty)
        for card in closedCards {
            XCTAssertEqual(card.form, .closed)
        }
    }

    func test_allCards_openCardsHaveCorrectForm() {
        let openCards = allCards.filter { $0.form == .open }
        XCTAssertFalse(openCards.isEmpty)
        for card in openCards {
            XCTAssertEqual(card.form, .open)
        }
    }

    // MARK: - acceptsBothDurations

    func test_acceptsBothDurations_setCorrectlyForDuplicateForms() {
        // Cards with acceptsBothDurations = true should have forms that appear in
        // both short and long positions of their vowel
        let bothDurationCards = allCards.filter { $0.acceptsBothDurations }

        for card in bothDurationCards {
            XCTAssertTrue(card.vowel.isDuplicate(form: card.display),
                          "Card '\(card.display)' marked as accepting both durations should actually be a duplicate form")
        }
    }

    func test_acceptsBothDurations_falseForNonDuplicateForms() {
        let singleDurationCards = allCards.filter { !$0.acceptsBothDurations }

        for card in singleDurationCards {
            XCTAssertFalse(card.vowel.isDuplicate(form: card.display),
                           "Card '\(card.display)' not marked as accepting both durations should not be a duplicate form")
        }
    }

    func test_acceptsBothDurations_alternativeDuration_nonNilForDuplicates() {
        let bothDurationCards = allCards.filter { $0.acceptsBothDurations }
        for card in bothDurationCards {
            XCTAssertNotNil(card.alternativeDuration,
                            "Card '\(card.display)' accepting both durations should have an alternative duration")
        }
    }

    func test_acceptsBothDurations_alternativeDuration_nilForNonDuplicates() {
        let singleDurationCards = allCards.filter { !$0.acceptsBothDurations }
        for card in singleDurationCards {
            XCTAssertNil(card.alternativeDuration,
                         "Card '\(card.display)' not accepting both durations should have nil alternative duration")
        }
    }

    func test_acceptsBothDurations_alternativeDuration_isOppositeDuration() {
        let bothDurationCards = allCards.filter { $0.acceptsBothDurations }
        for card in bothDurationCards {
            guard let alt = card.alternativeDuration else { continue }
            if card.duration == .short {
                XCTAssertEqual(alt, .long)
            } else {
                XCTAssertEqual(alt, .short)
            }
        }
    }

    // MARK: - Vowel.isDuplicate

    func test_vowelIsDuplicate_formInBothShortAndLong_returnsTrue() {
        // Find a vowel where a form appears in both short and long
        for vowel in allVowels {
            let shortForms = [vowel.short.closed, vowel.short.open].compactMap { $0 }
            let longForms = [vowel.long.closed, vowel.long.open].compactMap { $0 }
            let shared = Set(shortForms).intersection(Set(longForms))

            for form in shared {
                XCTAssertTrue(vowel.isDuplicate(form: form),
                              "Form '\(form)' appears in both short and long, isDuplicate should return true")
            }
        }
    }

    func test_vowelIsDuplicate_formInOnlyOnePosition_returnsFalse() {
        // Find a vowel where forms are unique to short or long
        for vowel in allVowels {
            let shortForms = [vowel.short.closed, vowel.short.open].compactMap { $0 }
            let longForms = [vowel.long.closed, vowel.long.open].compactMap { $0 }
            let shortOnly = Set(shortForms).subtracting(Set(longForms))
            let longOnly = Set(longForms).subtracting(Set(shortForms))

            for form in shortOnly {
                XCTAssertFalse(vowel.isDuplicate(form: form),
                               "Form '\(form)' only in short, isDuplicate should return false")
            }
            for form in longOnly {
                XCTAssertFalse(vowel.isDuplicate(form: form),
                               "Form '\(form)' only in long, isDuplicate should return false")
            }
        }
    }

    func test_vowelIsDuplicate_nonexistentForm_returnsFalse() {
        guard let vowel = allVowels.first else {
            XCTFail("Need at least one vowel")
            return
        }
        XCTAssertFalse(vowel.isDuplicate(form: "ZZZZZ"))
    }

    // MARK: - Card display values

    func test_allCards_displayValuesAreNonEmpty() {
        for card in allCards {
            XCTAssertFalse(card.display.isEmpty,
                           "Card at index should have a non-empty display value")
        }
    }

    // MARK: - Each card references a vowel

    func test_allCards_eachCardHasValidVowelReference() {
        for card in allCards {
            // The vowel's sound should be non-empty
            XCTAssertFalse(card.vowel.sound.isEmpty,
                           "Card '\(card.display)' should reference a vowel with a valid sound")
        }
    }

    // MARK: - VowelDuration

    func test_vowelDuration_labels_nonEmpty() {
        XCTAssertFalse(VowelCard.VowelDuration.short.label.isEmpty)
        XCTAssertFalse(VowelCard.VowelDuration.long.label.isEmpty)
    }

    func test_vowelDuration_rawValues() {
        XCTAssertEqual(VowelCard.VowelDuration.short.rawValue, "Short")
        XCTAssertEqual(VowelCard.VowelDuration.long.rawValue, "Long")
    }

    func test_vowelDuration_allCases() {
        XCTAssertEqual(VowelCard.VowelDuration.allCases.count, 2)
    }

    // MARK: - VowelFormType

    func test_vowelFormType_labels_nonEmpty() {
        XCTAssertFalse(VowelCard.VowelFormType.closed.label.isEmpty)
        XCTAssertFalse(VowelCard.VowelFormType.open.label.isEmpty)
    }

    func test_vowelFormType_rawValues() {
        XCTAssertEqual(VowelCard.VowelFormType.closed.rawValue, "Closed")
        XCTAssertEqual(VowelCard.VowelFormType.open.rawValue, "Open")
    }

    func test_vowelFormType_allCases() {
        XCTAssertEqual(VowelCard.VowelFormType.allCases.count, 2)
    }

    // MARK: - Vowel.isUncommon

    func test_vowelIsUncommon_vowelWithNilUsage_returnsFalse() {
        // Most vowels have nil usage (meaning common/default)
        guard let defaultVowel = allVowels.first(where: { $0.usage == nil }) else {
            XCTFail("No vowel with nil usage found")
            return
        }
        XCTAssertFalse(defaultVowel.isUncommon)
    }

    func test_vowelIsUncommon_uncommonVowel_returnsTrue() {
        guard let uncommonVowel = allVowels.first(where: {
            $0.usage == .uncommon || $0.usage == .rare || $0.usage == .archaic
        }) else {
            // Not all datasets may have uncommon vowels; skip gracefully
            return
        }
        XCTAssertTrue(uncommonVowel.isUncommon)
    }

    func test_vowelIsUncommon_nilUsage_returnsFalse() {
        // Vowels with nil usage should not be considered uncommon
        let nilUsageVowels = allVowels.filter { $0.usage == nil }
        for vowel in nilUsageVowels {
            XCTAssertFalse(vowel.isUncommon,
                           "Vowel with nil usage should not be uncommon")
        }
    }

    // MARK: - Reference detail audio roles

    func test_referenceWordSources_fallbackSampleIsPresentedOnceAsPronunciation() {
        let vowel = makeReferenceVowel(pronunciation: nil, sample: "กัน")

        let sources = vowelReferenceWordSources(for: vowel, duration: .short, form: .closed)

        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources.first?.role, .pronunciationExample)
        XCTAssertEqual(sources.first?.word.word, "กัน")
        XCTAssertEqual(sources.first?.soundType, .vowel)
        XCTAssertEqual(sources.first?.usesItemVoiceOverride, true)
    }

    func test_referenceWordSources_dedicatedPronunciationKeepsSampleDistinct() {
        let vowel = makeReferenceVowel(pronunciation: "กั้น", sample: "กัน")

        let sources = vowelReferenceWordSources(for: vowel, duration: .short, form: .closed)

        XCTAssertEqual(sources.count, 2)
        XCTAssertEqual(sources.map(\.role), [.pronunciationExample, .sampleWord])
        XCTAssertEqual(sources.map(\.word.word), ["กั้น", "กัน"])
        XCTAssertEqual(sources.map(\.soundType), [.vowel, .sampleWord])
        XCTAssertEqual(sources.map(\.usesItemVoiceOverride), [true, false])
    }

    func test_referenceAudioRoles_haveTypeSpecificLabels() {
        XCTAssertEqual(ReferencePrimaryAudioRole.name.rawValue, "Say Name")
        XCTAssertEqual(ReferencePrimaryAudioRole.cluster.rawValue, "Hear Cluster")
        XCTAssertEqual(ReferencePrimaryAudioRole.tone.rawValue, "Hear Tone")
        XCTAssertEqual(
            ReferenceWordAudioRole.pronunciationExample.rawValue,
            "Pronunciation Example"
        )
        XCTAssertEqual(ReferenceWordAudioRole.primaryExample.rawValue, "Primary Example")
        XCTAssertEqual(ReferenceWordAudioRole.additionalExample.rawValue, "Additional Example")
    }

    // MARK: - Helpers

    private func makeReferenceVowel(pronunciation: String?, sample: String) -> Vowel {
        Vowel(
            short: VowelForm(closed: "กั-", open: nil),
            long: VowelForm(closed: nil, open: nil),
            sounds: VowelSounds(en: "a"),
            notes: nil,
            rowNote: nil,
            pronunciations: VowelSamples(
                short_closed: pronunciation.map { ReferenceSampleWord(word: $0) },
                short_open: nil,
                long_closed: nil,
                long_open: nil
            ),
            samples: VowelSamples(
                short_closed: ReferenceSampleWord(word: sample),
                short_open: nil,
                long_closed: nil,
                long_open: nil
            ),
            usage: nil
        )
    }

    private func findDuplicates(in array: [String]) -> [String] {
        var seen = Set<String>()
        var duplicates: [String] = []
        for item in array {
            if seen.contains(item) {
                duplicates.append(item)
            }
            seen.insert(item)
        }
        return duplicates
    }
}

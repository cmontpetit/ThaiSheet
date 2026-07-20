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

    func test_toneMarkLoadAll_returns4ActualMarks() {
        // No no-mark row: unmarked syllables follow the tone rules,
        // not the tone-mark table (the old Mid/Mid row was wrong for
        // high-class syllables, which are Rising when live)
        let toneMarks = ToneMark.loadAll()
        XCTAssertEqual(toneMarks.count, 4)
        for toneMark in toneMarks {
            XCTAssertFalse(toneMark.mark.isEmpty, "Every row must be a real tone mark")
        }
    }

    func test_toneMarkLoadAll_maiTriAndChattawaAreMidClassOnly() {
        let toneMarks = ToneMark.loadAll()
        for mark in ["\u{0E4A}", "\u{0E4B}"] { // ๊ ๋
            let toneMark = toneMarks.first { $0.mark == mark }
            XCTAssertNotNil(toneMark)
            XCTAssertNil(toneMark?.onLow, "\(mark) is not used with low-class consonants")
            XCTAssertNotNil(toneMark?.onMid)
            XCTAssertNil(toneMark?.onHigh, "\(mark) is not used with high-class consonants")
        }
    }

    func test_toneMarkLoadAll_maiEkAndThoCoverAllThreeClasses() {
        let toneMarks = ToneMark.loadAll()
        for mark in ["\u{0E48}", "\u{0E49}"] { // ่ ้
            let toneMark = toneMarks.first { $0.mark == mark }
            XCTAssertNotNil(toneMark?.onLow)
            XCTAssertNotNil(toneMark?.onMid)
            XCTAssertNotNil(toneMark?.onHigh)
        }
    }

    func test_toneMarkCards_are8WithHighClassAndNoUnmarked() {
        let cards = ToneMarkCard.allCards(from: ToneMark.loadAll())
        XCTAssertEqual(cards.count, 8)
        XCTAssertEqual(
            Set(cards.map(\.display)),
            ["ค่า", "ค้า", "ก่า", "ก้า", "ก๊า", "ก๋า", "ข่า", "ข้า"],
            "2 low (ค) + 4 mid (ก) + 2 high (ข); no unmarked คา/กา cards"
        )
    }

    func test_toneMarkCards_highClassTonesAreCorrect() {
        let cards = ToneMarkCard.allCards(from: ToneMark.loadAll())
        XCTAssertEqual(cards.first { $0.display == "ข่า" }?.correctTone, "Low")
        XCTAssertEqual(cards.first { $0.display == "ข้า" }?.correctTone, "Falling")
        XCTAssertEqual(cards.first { $0.display == "ข่า" }?.consonantClass, .high)
    }

    func test_toneMarkCards_maiTriAndChattawaProduceMidCardsOnly() {
        let cards = ToneMarkCard.allCards(from: ToneMark.loadAll())
        for card in cards where card.toneMark.mark == "\u{0E4A}" || card.toneMark.mark == "\u{0E4B}" {
            XCTAssertEqual(card.consonantClass, .mid,
                           "\(card.display) must be a mid-class card")
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

    func test_toneRulePopupExamples_haveBundledAudio() {
        for rule in ToneRule.loadAll() {
            guard let sample = rule.samples?.dropFirst().first else {
                XCTFail("Tone rule \(rule.id) needs an additional popup example")
                continue
            }
            let filename = "cheat_sheet_tone_rule_\(sample.full)_neural2"
            let sound = Bundle.main.url(
                forResource: filename,
                withExtension: "mp3",
                subdirectory: "sounds"
            ) ?? Bundle.main.url(forResource: filename, withExtension: "mp3")
            XCTAssertNotNil(sound, "Missing tone-rule example audio for \(sample.full)")
            XCTAssertFalse(
                sample.romanization?.isEmpty ?? true,
                "Tone-rule example \(sample.full) needs romanization"
            )
            XCTAssertFalse(
                sample.meaning?.en.isEmpty ?? true,
                "Tone-rule example \(sample.full) needs an English meaning"
            )
            XCTAssertFalse(
                sample.meaning?.fr?.isEmpty ?? true,
                "Tone-rule example \(sample.full) needs a French meaning"
            )
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

    func test_clusterAudioKey_keepsDisplayNotationSeparateFromPlayback() {
        let initial = Cluster.loadAll().first { $0.cluster == "กร-" }
        XCTAssertEqual(initial?.cluster, "กร-")
        XCTAssertEqual(initial?.audioKey, "กรา")

        let final = Cluster.loadAll().first { $0.cluster == "-ทร" }
        XCTAssertEqual(final?.cluster, "-ทร")
        XCTAssertEqual(final?.audioKey, "-ทร")
    }

    func test_clusterAudioKeys_resolveToBundledSounds() {
        for cluster in Cluster.loadAll() {
            let filename = "cheat_sheet_cluster_\(cluster.audioKey)_neural2"
            let sound = Bundle.main.url(
                forResource: filename,
                withExtension: "mp3",
                subdirectory: "sounds"
            ) ?? Bundle.main.url(forResource: filename, withExtension: "mp3")
            XCTAssertNotNil(sound, "Missing cluster audio for \(cluster.cluster): \(cluster.audioKey)")
        }
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

    // MARK: - Content Corrections (Bucket A, July 2026 audit)

    func test_clusterSounds_aspiratedOnsetsKeepAspiration() {
        // ข/ค = kh-, พ = ph- in the consonant scheme; cluster romanization
        // must not drop the aspiration. (ผล- is deliberately not covered:
        // word-specific, pending verification.)
        let aspirated: [Character: String] = ["ข": "kh", "ค": "kh", "พ": "ph"]
        for cluster in Cluster.loadAll() where cluster.type == .smooth {
            guard let first = cluster.cluster.first, let prefix = aspirated[first] else { continue }
            XCTAssertTrue(cluster.sound?.hasPrefix(prefix) ?? false,
                          "\(cluster.cluster) should keep aspiration (\(prefix)-), got \(cluster.sound ?? "nil")")
        }
    }

    func test_chadaaTranscription_marksHighToneOnFirstSyllable() {
        // ช + short + dead → high tone: chá, matching the khǎaw rá khang precedent
        let chada = Consonant.loadAll().first { $0.character == "ฎ" }
        XCTAssertEqual(chada?.transcription, "daaw chá-daa")
    }

    func test_saraAm_isShortClosedOnly() {
        // ◌ำ is a short vowel + final /m/; น้ำ-style lengthening is lexical,
        // not a Long form of the pattern
        let ahm = Vowel.loadAll().first { $0.sound == "ahm" }
        XCTAssertEqual(ahm?.short.closed, "กำ")
        XCTAssertNil(ahm?.long.closed)
        XCTAssertNil(ahm?.long.open)
    }

    func test_aawyRow_examplesMatchVowelLength() {
        // บ่อย is short (the tone mark occupies ็'s position); it must not
        // be cited as a long -อย example
        let notes = Vowel.loadAll().first { $0.sound == "aawy" }?.notes?.en
        XCTAssertTrue(notes?.short_closed?.contains("บ่อย") ?? false,
                      "บ่อย belongs with the short ก็อย examples")
        XCTAssertFalse(notes?.long_closed?.contains("บ่อย") ?? true,
                       "บ่อย must not appear in the long กอย examples")
    }

    func test_vowelRowNotes_decodeWithFrench() {
        // The ฤ/ฤ-/ฦ rows carry row-level notes that were previously
        // silently dropped (model had no scalar note property)
        let rows = Vowel.loadAll().filter { $0.rowNote != nil }
        XCTAssertEqual(rows.count, 3, "ฤ (rue), ฤ- (ri), and ฦ (lue) rows carry row notes")
        for row in rows {
            XCTAssertFalse(row.rowNote?.en.isEmpty ?? true)
            XCTAssertFalse(row.rowNote?.fr?.isEmpty ?? true,
                           "Row note missing French: \(row.rowNote?.en ?? "")")
        }
    }

    func test_rueRowNote_documentsAllThreeReadings() {
        let note = Vowel.loadAll().first { $0.sound == "rue" }?.rowNote
        for reading in ["rue", "ri", "roe"] {
            XCTAssertTrue(note?.en.contains(reading) ?? false,
                          "ฤ note should document the \(reading) reading")
        }
        let lueNote = Vowel.loadAll().first { $0.sound == "lue" }?.rowNote
        XCTAssertTrue(lueNote?.en.contains("obsolete") ?? false,
                      "ฦ note should state the letters are obsolete")
    }

    func test_noteForForm_fallsBackToRowNote() {
        let rue = Vowel.loadAll().first { $0.sound == "rue" }
        XCTAssertNotNil(rue?.note(for: "Short", form: "Open"),
                        "Rows without keyed notes should surface their row note")
    }

    func test_riVowelForm_usesRealWordAudio() {
        func bundledSound(_ name: String) -> URL? {
            Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "sounds")
                ?? Bundle.main.url(forResource: name, withExtension: "mp3")
        }
        XCTAssertNotNil(bundledSound("cheat_sheet_vowel_ฤทธิ์_neural2"),
                        "the ri reading must use its explicit pronunciation word")
    }

    func test_vowelPronunciations_keepDuplicateSpellingsDistinct() {
        let vowel = Vowel.loadAll().first { $0.sound == "erh/uuhr" }
        XCTAssertEqual(vowel?.pronunciation(for: .short, form: .closed)?.word, "เงิน")
        XCTAssertEqual(vowel?.pronunciation(for: .long, form: .closed)?.word, "เดิน")
    }

    func test_vowelPronunciations_haveBundledRealWordAudio_orRemainSilent() {
        let expectedMissing = Set(["เกือะ", "ก็อย", "แก็ว", "เกอว", "ฦ"])
        var mappedCount = 0
        var missingForms = Set<String>()

        for vowel in Vowel.loadAll() {
            let variants: [(String?, VowelCard.VowelDuration, VowelCard.VowelFormType)] = [
                (vowel.short.closed, .short, .closed),
                (vowel.short.open, .short, .open),
                (vowel.long.closed, .long, .closed),
                (vowel.long.open, .long, .open),
            ]
            for (display, duration, form) in variants {
                guard let display else { continue }
                guard let pronunciation = vowel.pronunciation(for: duration, form: form) else {
                    missingForms.insert(display)
                    continue
                }
                mappedCount += 1
                let filename = "cheat_sheet_vowel_\(pronunciation.word)_neural2"
                let sound = Bundle.main.url(
                    forResource: filename,
                    withExtension: "mp3",
                    subdirectory: "sounds"
                ) ?? Bundle.main.url(forResource: filename, withExtension: "mp3")
                XCTAssertNotNil(sound, "Missing pronunciation audio for \(display): \(pronunciation.word)")
            }
        }

        XCTAssertEqual(mappedCount, 68)
        XCTAssertEqual(missingForms, expectedMissing)
    }

    // MARK: - Device Voice Text

    func test_liveText_consonantUsesFullLetterName() {
        XCTAssertEqual(AudioPlayer.liveText(for: .consonant, key: "ก"), "กอไก่")
    }

    func test_liveText_vowelUsesVisiblePronunciationWord() {
        XCTAssertEqual(AudioPlayer.liveText(for: .vowel, key: "กัน"), "กัน")
        XCTAssertEqual(AudioPlayer.liveText(for: .vowel, key: "เงิน"), "เงิน")
        XCTAssertEqual(AudioPlayer.liveText(for: .vowel, key: "ฤทธิ์"), "ฤทธิ์")
    }

    func test_liveText_sampleWordUsesThaiWord() {
        XCTAssertEqual(AudioPlayer.liveText(for: .sampleWord, key: "ไก่"), "ไก่")
    }

    func test_liveText_finalClusterRemovesNotationDash() {
        XCTAssertEqual(AudioPlayer.liveText(for: .cluster, key: "-ทร"), "ทร")
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

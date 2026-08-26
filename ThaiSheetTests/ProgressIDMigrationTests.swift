//
//  ProgressIDMigrationTests.swift
//  ThaiSheetTests
//
//  Durable progress IDs (#29): historical keys stay recognizable after content
//  edits, migration is idempotent and lossless, and normalization happens on
//  both sides before an iCloud merge.
//

import XCTest
@testable import ThaiSheet

final class ProgressIDMigrationTests: XCTestCase {

    // MARK: - Durable IDs are structural

    func test_cardIDs_carryNoDisplayContent() {
        let store = makeRetainedStore()

        for card in store.vowelCards {
            let id = FlashcardItem.vowel(card).id
            XCTAssertFalse(id.contains(card.display),
                           "Vowel card id \(id) still embeds its written form")
            XCTAssertTrue(id.hasSuffix(":\(card.duration.rawValue):\(card.form.rawValue)"),
                          "Vowel card id should be row id plus duration and form: \(id)")
        }
        for card in store.toneRuleCards {
            let id = FlashcardItem.toneRule(card).id
            XCTAssertFalse(id.contains(card.sample.full),
                           "Tone-rule card id \(id) still embeds its sample word")
        }
        for card in store.toneMarkCards {
            let id = FlashcardItem.toneMark(card).id
            XCTAssertFalse(id.contains(card.display),
                           "Tone-mark card id \(id) still embeds its rendered syllable")
        }
        for cluster in store.clusters {
            let id = FlashcardItem.cluster(cluster).id
            // Letters plus position, with the display dash notation dropped: a
            // substring check would pass on "-ทร" by accident, via the prefix.
            let letters = cluster.cluster.replacingOccurrences(of: "-", with: "")
            let position = cluster.cluster.hasPrefix("-") ? "final" : "initial"
            XCTAssertEqual(id, "cluster-\(letters):\(position)",
                           "Cluster card id should be letters plus position, free of dash notation")
        }
    }

    func test_durableIDs_areUniqueAcrossTheCatalog() {
        let store = makeRetainedStore()
        let ids = store.allCardsForTesting.map(\.id)
        let duplicates = Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.keys

        XCTAssertTrue(duplicates.isEmpty,
                      "Duplicate durable IDs would collide two cards' progress: \(Array(duplicates))")
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_dataFile_identifiersAreUnique() {
        let vowelIDs = Vowel.loadAll().map(\.id)
        XCTAssertEqual(vowelIDs.count, Set(vowelIDs).count, "vowels.json ids must be unique")
        XCTAssertFalse(vowelIDs.contains(where: \.isEmpty))

        for rule in ToneRule.loadAll() {
            let sampleIDs = (rule.samples ?? []).map(\.id)
            XCTAssertEqual(sampleIDs.count, Set(sampleIDs).count,
                           "Sample ids must be unique within rule \(rule.id)")
            XCTAssertFalse(sampleIDs.contains(where: \.isEmpty))
        }
    }

    // MARK: - Representative v1.2 migration

    func test_v1_2Keys_migrateToTodaysDurableIDs() {
        let store = makeRetainedStore()
        let durableIDs = Set(store.allCardsForTesting.map(\.id))

        // A sample of what a v1.2 device actually persisted, one per card type
        // whose scheme changed.
        let legacyKeys = [
            "vowel-กะ",
            "vowel-เกีย-",
            "toneMark-ค่า",
            "toneRule-Low-Short-Dead/None-คะ",
            "cluster-กร-",
            "cluster--ทร",
        ]
        for legacy in legacyKeys {
            guard let durable = LegacyProgressIDs.upToV1_2[legacy] else {
                return XCTFail("Frozen table is missing the v1.2 key \(legacy)")
            }
            XCTAssertTrue(durableIDs.contains(durable),
                          "\(legacy) maps to \(durable), which no current card owns")
        }

        let migrated = ProgressIDMigration.migrate(progress(for: legacyKeys))
        XCTAssertEqual(Set(migrated.keys), Set(legacyKeys.map { LegacyProgressIDs.upToV1_2[$0]! }))
        for (key, value) in migrated {
            XCTAssertEqual(value.cardId, key, "Re-keyed progress must carry the new id")
        }
    }

    func test_migration_preservesEveryReviewField() {
        let legacy = "toneMark-ค่า"
        let reviewed = Date(timeIntervalSince1970: 1_700_000_000)
        let stored = [legacy: CardProgress(
            cardId: legacy,
            correctCount: 5,
            incorrectCount: 2,
            lastReviewed: reviewed,
            srsStage: .familiar1,
            nextReviewDate: reviewed.addingTimeInterval(604_800)
        )]

        let migrated = ProgressIDMigration.migrate(stored)
        guard let value = migrated[LegacyProgressIDs.upToV1_2[legacy]!] else {
            return XCTFail("Expected the migrated entry")
        }
        XCTAssertEqual(value.correctCount, 5)
        XCTAssertEqual(value.incorrectCount, 2)
        XCTAssertEqual(value.lastReviewed, reviewed)
        XCTAssertEqual(value.srsStage, .familiar1)
        XCTAssertEqual(value.nextReviewDate, reviewed.addingTimeInterval(604_800))
    }

    /// The point of freezing the table: the map is not derived from content, so
    /// editing a sample word or a written form cannot orphan stored progress.
    func test_frozenTable_survivesContentEdits() {
        let store = makeRetainedStore()
        let durableIDs = Set(store.allCardsForTesting.map(\.id))

        // Every frozen entry must still land on a card that exists, and no entry
        // may reference display text that a content edit could move.
        for (legacy, durable) in LegacyProgressIDs.upToV1_2 {
            XCTAssertTrue(durableIDs.contains(durable),
                          "Frozen mapping \(legacy) -> \(durable) points at no current card")
        }

        // Simulate a content correction: a card whose sample word changed keeps
        // the same durable id, so the frozen mapping still resolves.
        let rule = ToneRule.loadAll()[0]
        let sample = rule.samples![0]
        let corrected = ToneSample(
            id: sample.id,
            full: "แก้ไข",
            focus: "แก้",
            note: sample.note,
            romanization: sample.romanization,
            meaning: sample.meaning
        )
        XCTAssertEqual(ToneRuleCard.key(rule: rule, sample: corrected),
                       ToneRuleCard.key(rule: rule, sample: sample),
                       "Correcting the sample word must not change its durable id")

        // Same for a cluster whose written form is re-notated (the dash moving,
        // or being dropped): identity lives in the data file, not the glyph.
        let cluster = store.clusters[0]
        let renotated = Cluster(
            id: cluster.id,
            cluster: "กร",
            sound: "kr-",
            type: cluster.type,
            usage: cluster.usage,
            note: cluster.note,
            sample: cluster.sample
        )
        XCTAssertEqual(FlashcardItem.cluster(renotated).id, FlashcardItem.cluster(cluster).id,
                       "Re-notating a cluster's written form must not change its durable id")
    }

    // MARK: - Voice-override ids (#29)

    func test_voiceOverrideIDs_migrateForVowelsAndClusters() {
        let store = makeRetainedStore()
        let legacyVowel = "vowel-aa/ah-กั-|กะ|กา-|กา"
        let legacyCluster = "cluster-กร-"

        let migrated = FlashcardSettings.migrateVoiceOverrideIDs([
            legacyVowel: .kore,
            legacyCluster: .matilda,
        ])

        let vowelDurable = FlashcardType.vowel.cardId(for: store.vowels[0].id)
        let clusterDurable = FlashcardType.cluster.cardId(for: store.clusters[0].id)
        XCTAssertEqual(migrated[vowelDurable], .kore,
                       "An existing vowel override must keep resolving after the id change")
        XCTAssertEqual(migrated[clusterDurable], .matilda)
        XCTAssertNil(migrated[legacyVowel])
        XCTAssertEqual(migrated.count, 2)

        // Every migrated id must name an item the catalog can still resolve.
        for id in migrated.keys {
            XCTAssertNotNil(store.voiceOverrideCatalogEntry(for: id),
                            "Override id \(id) no longer resolves to an item")
        }
    }

    func test_voiceOverrideIDMigration_isIdempotentAndKeepsUnknownIDs() {
        let legacyVowel = "vowel-aa/ah-กั-|กะ|กา-|กา"
        let unknown = "vowel-written-by-a-newer-build"
        let untouched = "toneMark-ค่า"

        let once = FlashcardSettings.migrateVoiceOverrideIDs([
            legacyVowel: .kore,
            unknown: .neural2,
            untouched: .device,
        ])
        let twice = FlashcardSettings.migrateVoiceOverrideIDs(once)

        XCTAssertEqual(once, twice)
        XCTAssertEqual(once[unknown], .neural2, "Unrecognized override ids are preserved")
        XCTAssertEqual(once[untouched], .device,
                       "Tone-mark overrides key on the sound key, which did not change")
        XCTAssertEqual(once.count, 3)
    }

    @MainActor
    func test_settings_migrateVoiceOverridesOnLoad_andPersistThem() throws {
        let legacyVowel = "vowel-aa/ah-กั-|กะ|กา-|กา"
        let store = InMemoryStore()
        store.set(FlashcardSettings.encodeVoiceOverrides([legacyVowel: .kore]),
                  forKey: "fc_voiceOverrides")

        let settings = FlashcardSettings(defaults: store)
        BundledFixtures.retain(settings, store)

        let durable = try XCTUnwrap(LegacyProgressIDs.voiceOverridesUpToV1_2[legacyVowel])
        XCTAssertEqual(settings.voiceOverride(for: durable), .kore)
        XCTAssertNil(settings.voiceOverride(for: legacyVowel))

        // Normalized form is written back, so a later reload has nothing to do.
        let persisted = FlashcardSettings.decodeVoiceOverrides(store.data(forKey: "fc_voiceOverrides"))
        XCTAssertEqual(Set(persisted.keys), [durable])
    }

    @MainActor
    func test_settings_reloadFromCloudBlob_migratesLegacyOverrideIDs() throws {
        // An iCloud change replaces the stored blob with an un-migrated one and
        // triggers reload(); the override must still resolve afterwards.
        let legacyCluster = "cluster-กร-"
        let store = InMemoryStore()
        let settings = FlashcardSettings(defaults: store)
        BundledFixtures.retain(settings, store)

        store.set(FlashcardSettings.encodeVoiceOverrides([legacyCluster: .matilda]),
                  forKey: "fc_voiceOverrides")
        settings.reload()

        let durable = try XCTUnwrap(LegacyProgressIDs.voiceOverridesUpToV1_2[legacyCluster])
        XCTAssertEqual(settings.voiceOverride(for: durable), .matilda)
        let persisted = FlashcardSettings.decodeVoiceOverrides(store.data(forKey: "fc_voiceOverrides"))
        XCTAssertEqual(Set(persisted.keys), [durable])
    }

    // MARK: - Skipped-version upgrades

    /// Every shipped release wrote the same keys (see LegacyProgressIDs), so a
    /// device jumping from v1.0 straight to the durable scheme migrates through
    /// the same table as one coming from v1.2.
    func test_skippedVersionUpgrade_migratesThroughTheSameTable() {
        let v1_0Keys = ["vowel-กะ", "toneRule-Low-Short-Dead/None-คะ"]
        let v1_2Keys = v1_0Keys

        let fromV1_0 = ProgressIDMigration.migrate(progress(for: v1_0Keys))
        let fromV1_2 = ProgressIDMigration.migrate(progress(for: v1_2Keys))

        XCTAssertEqual(Set(fromV1_0.keys), Set(fromV1_2.keys))
        XCTAssertFalse(fromV1_0.isEmpty)
        XCTAssertTrue(fromV1_0.keys.allSatisfy { LegacyProgressIDs.upToV1_2[$0] == nil },
                      "Migrated keys are durable, so they are not themselves legacy keys")
    }

    // MARK: - Idempotency, unknown keys, collisions

    func test_migration_isIdempotent() {
        let stored = progress(for: ["vowel-กะ", "toneMark-ค่า", "consonant-ก"])

        let once = ProgressIDMigration.migrate(stored)
        let twice = ProgressIDMigration.migrate(once)
        let thrice = ProgressIDMigration.migrate(twice)

        XCTAssertEqual(Set(once.keys), Set(twice.keys))
        XCTAssertEqual(Set(twice.keys), Set(thrice.keys))
    }

    func test_migration_keepsUnknownKeys() {
        let unknown = "vowel-from-a-newer-build"
        let stored = progress(for: ["vowel-กะ", unknown, "consonant-ก"])

        let migrated = ProgressIDMigration.migrate(stored)

        XCTAssertEqual(migrated.count, stored.count, "Migration must not drop entries")
        XCTAssertNotNil(migrated[unknown], "An unrecognized key is preserved, not deleted")
        XCTAssertNotNil(migrated["consonant-ก"], "Consonant keys never changed and pass through")
    }

    func test_migration_collision_keepsMostRecentlyReviewed() {
        let legacy = "toneMark-ค่า"
        let durable = LegacyProgressIDs.upToV1_2[legacy]!
        let older = Date(timeIntervalSince1970: 1_600_000_000)
        let newer = Date(timeIntervalSince1970: 1_700_000_000)

        let legacyWins = ProgressIDMigration.migrate([
            legacy: CardProgress(cardId: legacy, correctCount: 9, lastReviewed: newer, srsStage: .confident),
            durable: CardProgress(cardId: durable, correctCount: 1, lastReviewed: older, srsStage: .learning1),
        ])
        XCTAssertEqual(legacyWins.count, 1)
        XCTAssertEqual(legacyWins[durable]?.correctCount, 9)

        let durableWins = ProgressIDMigration.migrate([
            legacy: CardProgress(cardId: legacy, correctCount: 9, lastReviewed: older, srsStage: .confident),
            durable: CardProgress(cardId: durable, correctCount: 1, lastReviewed: newer, srsStage: .learning1),
        ])
        XCTAssertEqual(durableWins.count, 1)
        XCTAssertEqual(durableWins[durable]?.correctCount, 1)
    }

    // MARK: - Reordering and insertion do not move IDs

    func test_reorderingAndInsertingJSONRows_leavesExistingIDsUnchanged() throws {
        let vowels = Vowel.loadAll()
        let rules = ToneRule.loadAll()
        let originalVowelCards = VowelCard.allCards(from: vowels).map(\.id)
        let originalRuleCards = ToneRuleCard.allCards(from: rules).map(\.id)

        // Reverse the vowel rows and insert a new one at the front.
        let inserted = Vowel(
            id: "brand-new-row",
            short: VowelForm(closed: "ก็-", open: nil),
            long: VowelForm(closed: nil, open: nil),
            sounds: VowelSounds(en: "test"),
            notes: nil, rowNote: nil, pronunciations: nil, samples: nil, usage: nil
        )
        let shuffledVowels = [inserted] + vowels.reversed()
        let shuffledVowelCards = VowelCard.allCards(from: shuffledVowels).map(\.id)

        XCTAssertEqual(Set(originalVowelCards).subtracting(shuffledVowelCards), [],
                       "Reordering vowels.json must not change any existing card id")
        XCTAssertTrue(shuffledVowelCards.contains("brand-new-row:Short:Closed"),
                      "The inserted row gets its own id without disturbing the others")

        // Same for a rule whose samples are reordered and extended.
        let rule = try XCTUnwrap(rules.first)
        let samples = try XCTUnwrap(rule.samples)
        let newSample = ToneSample(id: "s999", full: "ทดสอบ", focus: "ทด")
        let reordered = ToneRule(
            initialConsonant: rule.initialConsonant,
            vowelDuration: rule.vowelDuration,
            end: rule.end,
            tone: rule.tone,
            samples: [newSample] + samples.reversed()
        )
        let reorderedCards = ToneRuleCard.allCards(from: [reordered]).map(\.id)
        let originalForRule = ToneRuleCard.allCards(from: [rule]).map(\.id)

        XCTAssertEqual(Set(originalForRule).subtracting(reorderedCards), [],
                       "Reordering a rule's samples must not change any existing card id")
        XCTAssertTrue(reorderedCards.contains("\(rule.id)#s999"))
        XCTAssertFalse(originalRuleCards.isEmpty)
    }

    // MARK: - Local and cloud normalization

    @MainActor
    func test_learningModel_migratesOnLoad_andPersistsDurableKeys() throws {
        let legacy = "toneMark-ค่า"
        let durable = LegacyProgressIDs.upToV1_2[legacy]!
        let store = InMemoryStore()
        store.set(try JSONEncoder().encode(progress(for: [legacy])), forKey: LearningModel.storageKey)

        let model = LearningModel(store: store)
        BundledFixtures.retain(model, store)

        XCTAssertEqual(model.getProgress(forId: durable).correctCount, 3)
        XCTAssertEqual(model.getProgress(forId: legacy).srsStage, .new,
                       "The legacy key is gone once migrated")

        // The normalized form is what is persisted, so this is a one-time cost.
        let persisted = try JSONDecoder().decode(
            [String: CardProgress].self,
            from: try XCTUnwrap(store.data(forKey: LearningModel.storageKey))
        )
        XCTAssertEqual(Set(persisted.keys), [durable])
        XCTAssertEqual(persisted[durable]?.cardId, durable)
    }

    func test_migrate_normalizesBothSidesBeforeMerge() {
        // What reconciliation compares: an old client's blob against a migrated
        // one. Normalizing both first is what makes them merge card-for-card.
        let legacy = "toneMark-ค่า"
        let durable = LegacyProgressIDs.upToV1_2[legacy]!
        let older = Date(timeIntervalSince1970: 1_600_000_000)
        let newer = Date(timeIntervalSince1970: 1_700_000_000)

        let fromOldClient = ProgressIDMigration.migrate([
            legacy: CardProgress(cardId: legacy, correctCount: 2, lastReviewed: older, srsStage: .learning2)
        ])
        let fromNewClient = ProgressIDMigration.migrate([
            durable: CardProgress(cardId: durable, correctCount: 7, lastReviewed: newer, srsStage: .familiar2)
        ])

        XCTAssertEqual(Set(fromOldClient.keys), Set(fromNewClient.keys),
                       "Both sides normalize to the same key, so the merge sees one card")

        // Merged with the store's most-recently-reviewed policy.
        var merged = fromOldClient
        for (key, cloud) in fromNewClient {
            let local = merged[key]
            if (cloud.lastReviewed ?? .distantPast) > (local?.lastReviewed ?? .distantPast) {
                merged[key] = cloud
            }
        }
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[durable]?.correctCount, 7)
    }

    // MARK: - Helpers

    private func progress(for ids: [String]) -> [String: CardProgress] {
        var result: [String: CardProgress] = [:]
        for (index, id) in ids.enumerated() {
            result[id] = CardProgress(
                cardId: id,
                correctCount: 3,
                incorrectCount: 0,
                lastReviewed: Date(timeIntervalSince1970: 1_650_000_000 + Double(index)),
                srsStage: .apprentice1,
                nextReviewDate: Date(timeIntervalSince1970: 1_650_100_000)
            )
        }
        return result
    }

    /// Bundle-backed and @Observable instances are retained for the process: a
    /// short-lived one trips the toolchain invalid-free described under Testing
    /// Gotchas in CLAUDE.md.
    private func makeRetainedStore() -> ThaiDataStore {
        let store = ThaiDataStore()
        BundledFixtures.retain(store)
        return store
    }
}

private enum BundledFixtures {
    static var retained: [AnyObject] = []

    static func retain(_ objects: AnyObject...) {
        retained.append(contentsOf: objects)
    }
}

private extension ThaiDataStore {
    /// Every card the catalog produces, for uniqueness checks.
    var allCardsForTesting: [FlashcardItem] {
        consonants.map(FlashcardItem.consonant)
            + vowelCards.map(FlashcardItem.vowel)
            + toneMarkCards.map(FlashcardItem.toneMark)
            + toneRuleCards.map(FlashcardItem.toneRule)
            + clusters.map(FlashcardItem.cluster)
    }
}

private final class InMemoryStore: KeyValueStore {
    private var values: [String: Any] = [:]

    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func set(_ value: Bool, forKey key: String) { values[key] = value }
    func object(forKey key: String) -> Any? { values[key] }
    func string(forKey key: String) -> String? { values[key] as? String }
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func removeObject(forKey key: String) { values.removeValue(forKey: key) }

    @discardableResult
    func synchronize() -> Bool { true }
}

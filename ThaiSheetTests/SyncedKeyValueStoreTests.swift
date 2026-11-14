//
//  SyncedKeyValueStoreTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

private final class InMemoryCloudKeyValueStore: CloudKeyValueStore {
    private var values: [String: Any] = [:]
    private(set) var writtenKeys: [String] = []
    private(set) var synchronizeCallCount = 0
    var synchronizeResult = true

    var notificationObject: AnyObject { self }

    func seed(_ value: Any, forKey key: String) {
        values[key] = value
    }

    func resetRecordedWrites() {
        writtenKeys = []
    }

    func set(_ value: Any, forKey key: String) {
        values[key] = value
        writtenKeys.append(key)
    }

    func object(forKey key: String) -> Any? {
        values[key]
    }

    func removeObject(forKey key: String) {
        values.removeValue(forKey: key)
        writtenKeys.append(key)
    }

    @discardableResult
    func synchronize() -> Bool {
        synchronizeCallCount += 1
        return synchronizeResult
    }
}

@MainActor
final class SyncedKeyValueStoreTests: XCTestCase {
    private var suiteName: String!
    private var local: UserDefaults!
    private var cloud: InMemoryCloudKeyValueStore!
    private var notificationCenter: NotificationCenter!
    private let syncDate = Date(timeIntervalSince1970: 3_000)

    override func setUp() {
        super.setUp()
        suiteName = "SyncedKeyValueStoreTests_\(UUID().uuidString)"
        local = UserDefaults(suiteName: suiteName)!
        cloud = InMemoryCloudKeyValueStore()
        notificationCenter = NotificationCenter()
    }

    override func tearDown() {
        local.removePersistentDomain(forName: suiteName)
        local = nil
        cloud = nil
        notificationCenter = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Activation and settings

    func test_activateCloud_reconcilesCloudBeforeSeedingLocalValues() {
        local.set(false, forKey: "fc_longVowels")
        cloud.seed(true, forKey: "fc_longVowels")
        let store = makeStore()

        store.activateCloud()

        XCTAssertEqual(local.object(forKey: "fc_longVowels") as? Bool, true)
        XCTAssertFalse(cloud.writtenKeys.contains("fc_longVowels"))
        XCTAssertEqual(cloud.synchronizeCallCount, 1)
    }

    func test_activateCloud_seedsOnlyMissingCloudValues() {
        local.set(false, forKey: "fc_shortVowels")
        let store = makeStore()

        store.activateCloud()

        XCTAssertEqual(cloud.object(forKey: "fc_shortVowels") as? Bool, false)
        XCTAssertTrue(cloud.writtenKeys.contains("fc_shortVowels"))
    }

    func test_activateCloud_doesNotSeedWhenCloudSnapshotCannotSynchronize() {
        local.set(false, forKey: "fc_shortVowels")
        cloud.synchronizeResult = false
        let store = makeStore()

        store.activateCloud()

        XCTAssertNil(cloud.object(forKey: "fc_shortVowels"))
        XCTAssertTrue(cloud.writtenKeys.isEmpty)
        XCTAssertNil(store.lastSyncDate)
    }

    func test_iCloudOptIn_remainsDeviceLocal() {
        let store = makeStore()

        store.set(true, forKey: "fc_iCloudSyncEnabled")

        XCTAssertEqual(local.object(forKey: "fc_iCloudSyncEnabled") as? Bool, true)
        XCTAssertNil(cloud.object(forKey: "fc_iCloudSyncEnabled"))
        XCTAssertFalse(cloud.writtenKeys.contains("fc_iCloudSyncEnabled"))
    }

    func test_externalSettingChange_reloadDoesNotRepublishAllSettings() {
        local.set(true, forKey: "fc_longVowels")
        cloud.seed(true, forKey: "fc_longVowels")
        let store = makeStore()
        store.activateCloud()
        let settings = FlashcardSettings(defaults: store)
        cloud.seed(false, forKey: "fc_longVowels")
        cloud.resetRecordedWrites()

        store.handleExternalChange(
            reason: NSUbiquitousKeyValueStoreServerChange,
            changedKeys: ["fc_longVowels"]
        )
        settings.reload()

        XCTAssertFalse(settings.longVowels)
        XCTAssertTrue(cloud.writtenKeys.isEmpty)
    }

    func test_externalChange_ignoresUnknownKeys() {
        local.set("local", forKey: "not-owned-by-sync")
        cloud.seed("cloud", forKey: "not-owned-by-sync")
        let store = makeStore()
        store.activateCloud()

        store.handleExternalChange(
            reason: NSUbiquitousKeyValueStoreServerChange,
            changedKeys: ["not-owned-by-sync"]
        )

        XCTAssertEqual(local.string(forKey: "not-owned-by-sync"), "local")
    }

    func test_externalChange_recordsDateAndPostsNotification() {
        let store = makeStore()
        store.activateCloud()
        var notificationCount = 0
        let token = notificationCenter.addObserver(
            forName: .syncedStoreDidChange,
            object: store,
            queue: nil
        ) { _ in
            notificationCount += 1
        }
        defer { notificationCenter.removeObserver(token) }

        store.handleExternalChange(
            reason: NSUbiquitousKeyValueStoreServerChange,
            changedKeys: []
        )

        XCTAssertEqual(store.lastSyncDate, syncDate)
        XCTAssertEqual(notificationCount, 1)
    }

    // MARK: - Learning progress reconciliation

    func test_activateCloud_mergesProgressThroughProductionPath() throws {
        let oldDate = Date(timeIntervalSince1970: 1_000)
        let newDate = Date(timeIntervalSince1970: 2_000)
        let localOnly = progress(id: "local-only", stage: .learning1, reviewed: oldDate)
        let localOlder = progress(id: "shared", stage: .learning1, reviewed: oldDate)
        let cloudNewer = progress(id: "shared", stage: .apprentice1, reviewed: newDate)
        local.set(try encoded(["local-only": localOnly, "shared": localOlder]),
                  forKey: LearningModel.storageKey)
        cloud.seed(try encoded(["shared": cloudNewer]), forKey: LearningModel.storageKey)
        let store = makeStore()

        store.activateCloud()

        let merged = try decoded(XCTUnwrap(local.data(forKey: LearningModel.storageKey)))
        XCTAssertEqual(merged["local-only"]?.srsStage, .learning1)
        XCTAssertEqual(merged["shared"]?.srsStage, .apprentice1)
        let cloudMerged = try decoded(XCTUnwrap(cloud.object(forKey: LearningModel.storageKey) as? Data))
        XCTAssertEqual(cloudMerged["local-only"]?.srsStage, .learning1)
    }

    func test_activateCloud_normalizesLegacyKeysOnBothSidesBeforeMerging() throws {
        // The upgrade case: this device still holds v1.2 keys while another
        // device has already migrated. Both blobs are normalized before the
        // merge, so one card stays one card (#29).
        let legacy = "toneMark-ค่า"
        let durable = try XCTUnwrap(LegacyProgressIDs.upToV1_2[legacy])
        let oldDate = Date(timeIntervalSince1970: 1_000)
        let newDate = Date(timeIntervalSince1970: 2_000)
        local.set(try encoded([legacy: progress(id: legacy, stage: .learning1, reviewed: oldDate)]),
                  forKey: LearningModel.storageKey)
        cloud.seed(try encoded([durable: progress(id: durable, stage: .apprentice1, reviewed: newDate)]),
                   forKey: LearningModel.storageKey)
        let store = makeStore()

        store.activateCloud()

        let merged = try decoded(XCTUnwrap(local.data(forKey: LearningModel.storageKey)))
        XCTAssertEqual(Set(merged.keys), [durable],
                       "The legacy and durable entries must collapse into one card, not two")
        XCTAssertEqual(merged[durable]?.srsStage, .apprentice1,
                       "The most recently reviewed side wins, as it does for any card")
    }

    func test_activateCloud_keepsUnknownKeysDuringNormalization() throws {
        // A key this build does not recognize (a newer client's) must survive
        // reconciliation rather than be dropped as unmigratable.
        let unknown = "vowel-written-by-a-newer-build"
        local.set(try encoded([unknown: progress(id: unknown, stage: .familiar1, reviewed: syncDate)]),
                  forKey: LearningModel.storageKey)
        cloud.seed(try encoded(["consonant-ก": progress(id: "consonant-ก", stage: .learning1, reviewed: syncDate)]),
                   forKey: LearningModel.storageKey)
        let store = makeStore()

        store.activateCloud()

        let merged = try decoded(XCTUnwrap(local.data(forKey: LearningModel.storageKey)))
        XCTAssertEqual(Set(merged.keys), [unknown, "consonant-ก"])
    }

    func test_activateCloud_preservesCorruptLocalProgressBeforeUsingCloud() throws {
        let corruptLocal = Data("not-json-local".utf8)
        let validCloud = ["card": progress(id: "card", stage: .learning2, reviewed: syncDate)]
        local.set(corruptLocal, forKey: LearningModel.storageKey)
        cloud.seed(try encoded(validCloud), forKey: LearningModel.storageKey)
        let store = makeStore()

        store.activateCloud()

        XCTAssertEqual(local.data(forKey: LearningModel.corruptedBackupKey), corruptLocal)
        let restored = try decoded(XCTUnwrap(local.data(forKey: LearningModel.storageKey)))
        XCTAssertEqual(restored["card"]?.srsStage, .learning2)
    }

    func test_activateCloud_preservesCorruptCloudProgressBeforeUsingLocal() throws {
        let corruptCloud = Data("not-json-cloud".utf8)
        let validLocal = ["card": progress(id: "card", stage: .familiar1, reviewed: syncDate)]
        local.set(try encoded(validLocal), forKey: LearningModel.storageKey)
        cloud.seed(corruptCloud, forKey: LearningModel.storageKey)
        let store = makeStore()

        store.activateCloud()

        XCTAssertEqual(local.data(forKey: LearningModel.corruptedCloudBackupKey), corruptCloud)
        let repairedCloud = try decoded(XCTUnwrap(cloud.object(forKey: LearningModel.storageKey) as? Data))
        XCTAssertEqual(repairedCloud["card"]?.srsStage, .familiar1)
    }

    func test_activateCloud_preservesBothCorruptBlobsWithoutOverwritingEither() {
        let corruptLocal = Data("not-json-local".utf8)
        let corruptCloud = Data("not-json-cloud".utf8)
        local.set(corruptLocal, forKey: LearningModel.storageKey)
        cloud.seed(corruptCloud, forKey: LearningModel.storageKey)
        let store = makeStore()

        store.activateCloud()

        XCTAssertEqual(local.data(forKey: LearningModel.storageKey), corruptLocal)
        XCTAssertEqual(cloud.object(forKey: LearningModel.storageKey) as? Data, corruptCloud)
        XCTAssertEqual(local.data(forKey: LearningModel.corruptedBackupKey), corruptLocal)
        XCTAssertEqual(local.data(forKey: LearningModel.corruptedCloudBackupKey), corruptCloud)
        XCTAssertFalse(cloud.writtenKeys.contains(LearningModel.storageKey))
    }

    func test_mergeProgress_keepsNewestVersionForEachCard() {
        let oldDate = Date(timeIntervalSince1970: 1_000)
        let newDate = Date(timeIntervalSince1970: 2_000)
        let local = [
            "local-wins": progress(id: "local-wins", stage: .familiar1, reviewed: newDate),
            "cloud-wins": progress(id: "cloud-wins", stage: .learning1, reviewed: oldDate),
        ]
        let cloud = [
            "local-wins": progress(id: "local-wins", stage: .learning2, reviewed: oldDate),
            "cloud-wins": progress(id: "cloud-wins", stage: .apprentice2, reviewed: newDate),
        ]

        let merged = SyncedKeyValueStore.mergeProgress(local: local, cloud: cloud)

        XCTAssertEqual(merged["local-wins"]?.srsStage, .familiar1)
        XCTAssertEqual(merged["cloud-wins"]?.srsStage, .apprentice2)
    }

    // MARK: - Reset All Progress across devices

    func test_reset_isNotUndoneByAnotherDevicesProgress() throws {
        // This device reset at 2_000. Another device then merged its own
        // pre-reset cards back into the cloud blob.
        let resetDate = Date(timeIntervalSince1970: 2_000)
        local.set(resetDate, forKey: LearningModel.resetDateKey)
        local.set(try encoded([:]), forKey: LearningModel.storageKey)
        cloud.seed(resetDate, forKey: LearningModel.resetDateKey)
        cloud.seed(try encoded(["card": progress(id: "card", stage: .familiar1,
                                                 reviewed: Date(timeIntervalSince1970: 1_000))]),
                   forKey: LearningModel.storageKey)
        let store = makeStore()
        store.activateCloud()
        cloud.resetRecordedWrites()

        store.handleExternalChange(
            reason: NSUbiquitousKeyValueStoreServerChange,
            changedKeys: [LearningModel.storageKey]
        )

        let kept = try decoded(XCTUnwrap(local.data(forKey: LearningModel.storageKey)))
        XCTAssertTrue(kept.isEmpty, "A card last reviewed before the reset must not come back")
        XCTAssertFalse(cloud.writtenKeys.contains(LearningModel.storageKey),
                       "Rewriting the cloud would only make the other device put the card back again")
    }

    func test_reset_fromAnotherDevice_dropsLocalProgressAndKeepsLaterReviews() throws {
        let resetDate = Date(timeIntervalSince1970: 2_000)
        local.set(try encoded([
            "before": progress(id: "before", stage: .familiar1, reviewed: Date(timeIntervalSince1970: 1_000)),
            "after": progress(id: "after", stage: .learning1, reviewed: Date(timeIntervalSince1970: 2_500)),
        ]), forKey: LearningModel.storageKey)
        let store = makeStore()
        store.activateCloud()
        cloud.seed(resetDate, forKey: LearningModel.resetDateKey)
        cloud.seed(try encoded([:]), forKey: LearningModel.storageKey)

        store.handleExternalChange(
            reason: NSUbiquitousKeyValueStoreServerChange,
            changedKeys: [LearningModel.resetDateKey]
        )

        XCTAssertEqual(local.object(forKey: LearningModel.resetDateKey) as? Date, resetDate)
        let kept = try decoded(XCTUnwrap(local.data(forKey: LearningModel.storageKey)))
        XCTAssertEqual(Set(kept.keys), ["after"])
        let cloudKept = try decoded(XCTUnwrap(cloud.object(forKey: LearningModel.storageKey) as? Data))
        XCTAssertEqual(Set(cloudKept.keys), ["after"], "A review made after the reset still syncs")
    }

    func test_resetAllProgress_publishesTheResetDate() throws {
        let store = makeStore()
        store.activateCloud()
        let model = LearningModel(store: store)
        let resetDate = Date(timeIntervalSince1970: 5_000)
        model.clock = { resetDate }

        model.resetAllProgress()

        XCTAssertEqual(local.object(forKey: LearningModel.resetDateKey) as? Date, resetDate)
        XCTAssertEqual(cloud.object(forKey: LearningModel.resetDateKey) as? Date, resetDate)
    }

    func test_activateCloud_takesTheLatestResetDateFromEitherSide() {
        let earlier = Date(timeIntervalSince1970: 1_000)
        let later = Date(timeIntervalSince1970: 2_000)
        local.set(later, forKey: LearningModel.resetDateKey)
        cloud.seed(earlier, forKey: LearningModel.resetDateKey)
        let store = makeStore()

        store.activateCloud()

        XCTAssertEqual(local.object(forKey: LearningModel.resetDateKey) as? Date, later)
        XCTAssertEqual(cloud.object(forKey: LearningModel.resetDateKey) as? Date, later)
    }

    // MARK: - Unchanged progress is not rewritten

    func test_externalChange_withTheSameProgress_writesNothingToTheCloud() throws {
        let cards = [
            "a": progress(id: "a", stage: .learning1, reviewed: Date(timeIntervalSince1970: 1_000)),
            "b": progress(id: "b", stage: .familiar1, reviewed: Date(timeIntervalSince1970: 2_000)),
        ]
        local.set(try encoded(cards), forKey: LearningModel.storageKey)
        cloud.seed(try encoded(cards), forKey: LearningModel.storageKey)
        let store = makeStore()
        store.activateCloud()
        cloud.resetRecordedWrites()

        store.handleExternalChange(
            reason: NSUbiquitousKeyValueStoreServerChange,
            changedKeys: [LearningModel.storageKey]
        )

        XCTAssertTrue(cloud.writtenKeys.isEmpty,
                      "A write here reaches the other device as a change, which answers with its own")
    }

    func test_externalChange_withNewerCloudCard_updatesLocalOnly() throws {
        let older = progress(id: "card", stage: .learning1, reviewed: Date(timeIntervalSince1970: 1_000))
        let newer = progress(id: "card", stage: .learning2, reviewed: Date(timeIntervalSince1970: 2_000))
        local.set(try encoded(["card": older]), forKey: LearningModel.storageKey)
        cloud.seed(try encoded(["card": older]), forKey: LearningModel.storageKey)
        let store = makeStore()
        store.activateCloud()
        cloud.seed(try encoded(["card": newer]), forKey: LearningModel.storageKey)
        cloud.resetRecordedWrites()

        store.handleExternalChange(
            reason: NSUbiquitousKeyValueStoreServerChange,
            changedKeys: [LearningModel.storageKey]
        )

        let merged = try decoded(XCTUnwrap(local.data(forKey: LearningModel.storageKey)))
        XCTAssertEqual(merged["card"]?.srsStage, .learning2)
        XCTAssertTrue(cloud.writtenKeys.isEmpty, "The cloud already holds the merged result")
    }

    // MARK: - Helpers

    private func makeStore() -> SyncedKeyValueStore {
        SyncedKeyValueStore(
            local: local,
            cloud: cloud,
            notificationCenter: notificationCenter,
            now: { self.syncDate }
        )
    }

    private func progress(
        id: String,
        stage: SRSStage,
        reviewed: Date
    ) -> CardProgress {
        var value = CardProgress(cardId: id)
        value.srsStage = stage
        value.lastReviewed = reviewed
        return value
    }

    private func encoded(_ progress: [String: CardProgress]) throws -> Data {
        try JSONEncoder().encode(progress)
    }

    private func decoded(_ data: Data) throws -> [String: CardProgress] {
        try JSONDecoder().decode([String: CardProgress].self, from: data)
    }
}

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

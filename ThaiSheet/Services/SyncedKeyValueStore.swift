//
//  SyncedKeyValueStore.swift
//  ThaiSheet
//

import Foundation

/// Notification posted when external iCloud changes are applied to local storage
extension Notification.Name {
    static let syncedStoreDidChange = Notification.Name("SyncedStoreDidChange")
}

/// The small cloud-store surface used by `SyncedKeyValueStore`.
/// Kept separate from `KeyValueStore` because the ubiquitous store's `set` API
/// does not accept optional values. Tests inject an in-memory implementation.
protocol CloudKeyValueStore: AnyObject {
    var notificationObject: AnyObject { get }
    func set(_ value: Any, forKey key: String)
    func object(forKey key: String) -> Any?
    func removeObject(forKey key: String)
    @discardableResult func synchronize() -> Bool
}

private final class UbiquitousCloudKeyValueStore: CloudKeyValueStore {
    private let store: NSUbiquitousKeyValueStore

    init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
    }

    var notificationObject: AnyObject { store }

    func set(_ value: Any, forKey key: String) {
        store.set(value, forKey: key)
    }

    func object(forKey key: String) -> Any? {
        store.object(forKey: key)
    }

    func removeObject(forKey key: String) {
        store.removeObject(forKey: key)
    }

    @discardableResult
    func synchronize() -> Bool {
        store.synchronize()
    }
}

/// A key-value store that writes selected values to local UserDefaults and iCloud.
/// Reads come from local storage for speed. Cloud sync activates only after the
/// user opts in on this device.
final class SyncedKeyValueStore: KeyValueStore {
    private static let lastSyncDateKey = "sync_lastSyncDate"
    private static let cloudSyncedKeys = Set(
        FlashcardSettings.syncedKeys + [LearningModel.storageKey, LearningModel.resetDateKey]
    )

    private let local: UserDefaults
    private let cloud: CloudKeyValueStore
    private let notificationCenter: NotificationCenter
    private let now: () -> Date
    /// Legacy → durable card-ID map applied to every decoded progress blob,
    /// local and cloud alike, before the two are compared (issue #29).
    private let idMigrationMap: [String: String]

    /// Last time a cloud reconciliation completed.
    private(set) var lastSyncDate: Date?

    /// Whether cloud sync is currently active.
    private var cloudActive = false
    private var observer: NSObjectProtocol?

    init(
        local: UserDefaults = .standard,
        cloud: CloudKeyValueStore = UbiquitousCloudKeyValueStore(),
        notificationCenter: NotificationCenter = .default,
        now: @escaping () -> Date = Date.init,
        idMigrationMap: [String: String] = ProgressIDMigration.bundled
    ) {
        self.local = local
        self.cloud = cloud
        self.notificationCenter = notificationCenter
        self.now = now
        self.idMigrationMap = idMigrationMap
        lastSyncDate = local.object(forKey: Self.lastSyncDateKey) as? Date

        if local.object(forKey: "fc_iCloudSyncEnabled") as? Bool == true {
            activateCloud()
        }
    }

    deinit {
        if let observer {
            notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Cloud Activation

    /// Start syncing with iCloud. Existing cloud data is reconciled before any
    /// missing cloud values are seeded from this device.
    func activateCloud() {
        guard !cloudActive else { return }
        cloudActive = true

        observer = notificationCenter.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud.notificationObject,
            queue: .main
        ) { [weak self] notification in
            self?.handleExternalChange(notification)
        }

        // Refresh the ubiquitous store's local cache, then reconcile cloud-first.
        // A later initial-sync notification will reconcile again if newer data arrives.
        // A failed synchronization means the in-memory cloud snapshot is not a
        // safe basis for deciding that a key is missing. Wait for a later external
        // change instead of seeding potentially stale local values.
        guard cloud.synchronize() else { return }
        reconcileAllKeys()
        finishCloudChange()
    }

    /// Stop syncing with iCloud. Called when the user disables sync on this device.
    func deactivateCloud() {
        guard cloudActive else { return }
        if let observer {
            notificationCenter.removeObserver(observer)
            self.observer = nil
        }
        cloudActive = false
    }

    // MARK: - KeyValueStore Conformance

    func set(_ value: Any?, forKey key: String) {
        local.set(value, forKey: key)

        if key == "fc_iCloudSyncEnabled" {
            value as? Bool == true ? activateCloud() : deactivateCloud()
            return
        }

        guard cloudActive, Self.cloudSyncedKeys.contains(key) else { return }
        if let value {
            cloud.set(value, forKey: key)
        } else {
            cloud.removeObject(forKey: key)
        }
    }

    func set(_ value: Bool, forKey key: String) {
        set(value as Any?, forKey: key)
    }

    func object(forKey key: String) -> Any? {
        local.object(forKey: key)
    }

    func string(forKey key: String) -> String? {
        local.string(forKey: key)
    }

    func data(forKey key: String) -> Data? {
        local.data(forKey: key)
    }

    func removeObject(forKey key: String) {
        local.removeObject(forKey: key)
        if cloudActive, Self.cloudSyncedKeys.contains(key) {
            cloud.removeObject(forKey: key)
        }
    }

    @discardableResult
    func synchronize() -> Bool {
        if cloudActive {
            cloud.synchronize()
        }
        return local.synchronize()
    }

    // MARK: - Reconciliation

    private func reconcileAllKeys() {
        for key in FlashcardSettings.syncedKeys {
            if let cloudValue = cloud.object(forKey: key) {
                // Cloud wins when both stores have a setting. This prevents a stale
                // device that is re-enabling sync from clobbering the cloud value.
                local.set(cloudValue, forKey: key)
            } else if let localValue = local.object(forKey: key) {
                cloud.set(localValue, forKey: key)
            }
        }

        reconcileLearningProgress()
    }

    private func handleExternalChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        else { return }

        handleExternalChange(reason: reason, changedKeys: changedKeys)
    }

    /// Internal seam used by tests to exercise the production change handler.
    func handleExternalChange(reason: Int, changedKeys: [String]) {
        guard cloudActive,
              reason == NSUbiquitousKeyValueStoreServerChange ||
              reason == NSUbiquitousKeyValueStoreInitialSyncChange
        else { return }

        var progressChanged = false
        for key in changedKeys {
            if key == LearningModel.storageKey || key == LearningModel.resetDateKey {
                progressChanged = true
            } else if FlashcardSettings.syncedKeys.contains(key) {
                if let cloudValue = cloud.object(forKey: key) {
                    local.set(cloudValue, forKey: key)
                } else {
                    local.removeObject(forKey: key)
                }
            }
        }
        if progressChanged {
            reconcileLearningProgress()
        }

        finishCloudChange()
    }

    private func finishCloudChange() {
        lastSyncDate = now()
        local.set(lastSyncDate, forKey: Self.lastSyncDateKey)
        notificationCenter.post(name: .syncedStoreDidChange, object: self)
    }

    private enum DecodedProgress {
        case missing
        /// `stored` is the blob as it decodes. `current` is what it means now:
        /// legacy IDs migrated, cards from before the latest reset dropped.
        case valid(stored: [String: CardProgress], current: [String: CardProgress])
        case corrupted(Data)
    }

    /// The latest "Reset All Progress" either side knows of, copied to
    /// whichever side is behind.
    private func reconcileResetDate() -> Date? {
        let localDate = local.object(forKey: LearningModel.resetDateKey) as? Date
        let cloudDate = cloud.object(forKey: LearningModel.resetDateKey) as? Date
        guard let latest = [localDate, cloudDate].compactMap({ $0 }).max() else { return nil }
        if localDate != latest {
            local.set(latest, forKey: LearningModel.resetDateKey)
        }
        if cloudDate != latest {
            cloud.set(latest, forKey: LearningModel.resetDateKey)
        }
        return latest
    }

    private func reconcileLearningProgress() {
        let resetDate = reconcileResetDate()
        let localProgress = decodeLearningProgress(
            local.data(forKey: LearningModel.storageKey), resetDate: resetDate)
        let cloudProgress = decodeLearningProgress(
            cloud.object(forKey: LearningModel.storageKey) as? Data, resetDate: resetDate)

        switch (localProgress, cloudProgress) {
        case (.missing, .missing):
            return

        case let (.valid(stored, current), .missing):
            writeProgress(current, toLocal: current != stored, toCloud: true)

        case let (.missing, .valid(_, current)):
            writeProgress(current, toLocal: true, toCloud: false)

        case let (.valid(localStored, localCurrent), .valid(_, cloudCurrent)):
            let merged = Self.mergeProgress(local: localCurrent, cloud: cloudCurrent)
            // Write a side only when the merge changes what it holds. An
            // unconditional cloud write is seen by every other device as a
            // change (the encoded bytes differ on each launch even for equal
            // progress), and each of them would answer with a write of its own.
            // A cloud blob that differs only by legacy IDs or by cards from
            // before the reset is left alone for the same reason: a device on
            // an older build keeps putting those back.
            writeProgress(merged, toLocal: merged != localStored, toCloud: merged != cloudCurrent)

        case let (.corrupted(localData), .valid(_, cloudCurrent)):
            preserveCorrupted(localData, forKey: LearningModel.corruptedBackupKey)
            writeProgress(cloudCurrent)

        case let (.valid(_, localCurrent), .corrupted(cloudData)):
            preserveCorrupted(cloudData, forKey: LearningModel.corruptedCloudBackupKey)
            writeProgress(localCurrent)

        case let (.corrupted(localData), .corrupted(cloudData)):
            preserveCorrupted(localData, forKey: LearningModel.corruptedBackupKey)
            preserveCorrupted(cloudData, forKey: LearningModel.corruptedCloudBackupKey)

        case let (.corrupted(localData), .missing):
            preserveCorrupted(localData, forKey: LearningModel.corruptedBackupKey)

        case let (.missing, .corrupted(cloudData)):
            preserveCorrupted(cloudData, forKey: LearningModel.corruptedCloudBackupKey)
        }
    }

    /// Merge progress card-by-card, keeping whichever review happened most recently.
    static func mergeProgress(
        local: [String: CardProgress],
        cloud: [String: CardProgress]
    ) -> [String: CardProgress] {
        var merged = local
        for (cardId, cloudCard) in cloud {
            guard let localCard = merged[cardId] else {
                merged[cardId] = cloudCard
                continue
            }

            if (cloudCard.lastReviewed ?? .distantPast) >
                (localCard.lastReviewed ?? .distantPast) {
                merged[cardId] = cloudCard
            }
        }
        return merged
    }

    /// Progress recorded after `resetDate`. Review times come from each
    /// device's own clock, so a review made on a device whose clock runs
    /// behind the resetting device's can be dropped with the rest.
    static func progress(
        _ progress: [String: CardProgress],
        after resetDate: Date?
    ) -> [String: CardProgress] {
        guard let resetDate else { return progress }
        return progress.filter { ($0.value.lastReviewed ?? .distantPast) > resetDate }
    }

    private func decodeLearningProgress(_ data: Data?, resetDate: Date?) -> DecodedProgress {
        guard let data else { return .missing }
        guard let progress = try? JSONDecoder().decode([String: CardProgress].self, from: data) else {
            return .corrupted(data)
        }
        // Both sides are normalized before reconciliation, so a blob from a
        // device that has not migrated yet merges card-for-card with one that
        // has, instead of producing two entries for the same card (issue #29).
        let migrated = ProgressIDMigration.migrate(progress, using: idMigrationMap)
        return .valid(stored: progress, current: Self.progress(migrated, after: resetDate))
    }

    private func writeProgress(
        _ progress: [String: CardProgress],
        toLocal: Bool = true,
        toCloud: Bool = true
    ) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        if toLocal {
            local.set(data, forKey: LearningModel.storageKey)
        }
        if toCloud {
            cloud.set(data, forKey: LearningModel.storageKey)
        }
    }

    private func preserveCorrupted(_ data: Data, forKey key: String) {
        local.set(data, forKey: key)
    }
}

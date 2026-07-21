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
    private static let cloudSyncedKeys = Set(FlashcardSettings.syncedKeys + [LearningModel.storageKey])

    private let local: UserDefaults
    private let cloud: CloudKeyValueStore
    private let notificationCenter: NotificationCenter
    private let now: () -> Date

    /// Last time a cloud reconciliation completed.
    private(set) var lastSyncDate: Date?

    /// Whether cloud sync is currently active.
    private var cloudActive = false
    private var observer: NSObjectProtocol?

    init(
        local: UserDefaults = .standard,
        cloud: CloudKeyValueStore = UbiquitousCloudKeyValueStore(),
        notificationCenter: NotificationCenter = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.local = local
        self.cloud = cloud
        self.notificationCenter = notificationCenter
        self.now = now
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

        for key in changedKeys {
            if key == LearningModel.storageKey {
                reconcileLearningProgress()
            } else if FlashcardSettings.syncedKeys.contains(key) {
                if let cloudValue = cloud.object(forKey: key) {
                    local.set(cloudValue, forKey: key)
                } else {
                    local.removeObject(forKey: key)
                }
            }
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
        case valid([String: CardProgress])
        case corrupted(Data)
    }

    private func reconcileLearningProgress() {
        let localProgress = decodeLearningProgress(local.data(forKey: LearningModel.storageKey))
        let cloudProgress = decodeLearningProgress(cloud.object(forKey: LearningModel.storageKey) as? Data)

        switch (localProgress, cloudProgress) {
        case (.missing, .missing):
            return

        case let (.valid(localValue), .missing):
            writeProgress(localValue, toLocal: false, toCloud: true)

        case let (.missing, .valid(cloudValue)):
            writeProgress(cloudValue, toLocal: true, toCloud: false)

        case let (.valid(localValue), .valid(cloudValue)):
            writeProgress(Self.mergeProgress(local: localValue, cloud: cloudValue))

        case let (.corrupted(localData), .valid(cloudValue)):
            preserveCorrupted(localData, forKey: LearningModel.corruptedBackupKey)
            writeProgress(cloudValue)

        case let (.valid(localValue), .corrupted(cloudData)):
            preserveCorrupted(cloudData, forKey: LearningModel.corruptedCloudBackupKey)
            writeProgress(localValue)

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

    private func decodeLearningProgress(_ data: Data?) -> DecodedProgress {
        guard let data else { return .missing }
        guard let progress = try? JSONDecoder().decode([String: CardProgress].self, from: data) else {
            return .corrupted(data)
        }
        return .valid(progress)
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

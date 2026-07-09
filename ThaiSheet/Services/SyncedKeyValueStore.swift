//
//  SyncedKeyValueStore.swift
//  ThaiSheet
//

import Foundation

/// Notification posted when external iCloud changes are applied to local storage
extension Notification.Name {
    static let syncedStoreDidChange = Notification.Name("SyncedStoreDidChange")
}

/// A key-value store that writes to both local UserDefaults and iCloud NSUbiquitousKeyValueStore.
/// Reads come from local UserDefaults for speed. Cloud sync only activates when iCloudSyncEnabled is true.
class SyncedKeyValueStore: KeyValueStore {
    private let local: UserDefaults

    /// Last time an external sync was received
    var lastSyncDate: Date?

    /// Whether cloud sync is currently active
    private var cloudActive = false
    private var cloud: NSUbiquitousKeyValueStore?
    private var observer: NSObjectProtocol?

    init(local: UserDefaults = .standard) {
        self.local = local

        // Load persisted last sync date
        if let date = local.object(forKey: "sync_lastSyncDate") as? Date {
            lastSyncDate = date
        }

        // Activate cloud if previously enabled
        if local.object(forKey: "fc_iCloudSyncEnabled") as? Bool == true {
            activateCloud()
        }
    }

    deinit {
        deactivateCloud()
    }

    // MARK: - Cloud Activation

    /// Start syncing with iCloud. Called when user enables iCloud sync.
    func activateCloud() {
        guard !cloudActive else { return }
        let kvStore = NSUbiquitousKeyValueStore.default
        self.cloud = kvStore
        cloudActive = true

        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore,
            queue: .main
        ) { [weak self] notification in
            self?.handleExternalChange(notification)
        }

        // Push all current local data to cloud
        pushAllToCloud()

        kvStore.synchronize()
    }

    /// Stop syncing with iCloud. Called when user disables iCloud sync.
    func deactivateCloud() {
        guard cloudActive else { return }
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        cloud = nil
        cloudActive = false
    }

    // MARK: - KeyValueStore Conformance

    func set(_ value: Any?, forKey key: String) {
        local.set(value, forKey: key)
        cloud?.set(value, forKey: key)

        // Handle sync toggle changes
        if key == "fc_iCloudSyncEnabled" {
            if value as? Bool == true {
                activateCloud()
            } else {
                deactivateCloud()
            }
        }
    }

    func set(_ value: Bool, forKey key: String) {
        local.set(value, forKey: key)
        cloud?.set(value, forKey: key)

        if key == "fc_iCloudSyncEnabled" {
            if value {
                activateCloud()
            } else {
                deactivateCloud()
            }
        }
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
        cloud?.removeObject(forKey: key)
    }

    @discardableResult
    func synchronize() -> Bool {
        cloud?.synchronize()
        return local.synchronize()
    }

    // MARK: - Push Local to Cloud

    /// Push all known keys from local to cloud (used on first enable)
    private func pushAllToCloud() {
        guard let cloud = cloud else { return }

        for key in FlashcardSettings.syncedKeys {
            if let value = local.object(forKey: key) {
                cloud.set(value, forKey: key)
            }
        }

        // Push learning progress
        if let data = local.data(forKey: LearningModel.storageKey) {
            cloud.set(data, forKey: LearningModel.storageKey)
        }
    }

    // MARK: - External Change Handling

    private func handleExternalChange(_ notification: Notification) {
        guard cloudActive,
              let cloud = cloud,
              let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        else { return }

        // Only process server changes and initial syncs
        guard changeReason == NSUbiquitousKeyValueStoreServerChange ||
              changeReason == NSUbiquitousKeyValueStoreInitialSyncChange
        else { return }

        for key in changedKeys {
            if key == LearningModel.storageKey {
                mergeLearningProgress(cloud: cloud)
            } else {
                // For settings keys, cloud value wins (last-write-wins)
                if let cloudValue = cloud.object(forKey: key) {
                    local.set(cloudValue, forKey: key)
                } else {
                    local.removeObject(forKey: key)
                }
            }
        }

        lastSyncDate = Date()
        local.set(lastSyncDate, forKey: "sync_lastSyncDate")

        // Notify models to reload
        NotificationCenter.default.post(name: .syncedStoreDidChange, object: self)
    }

    /// Merge learning progress by comparing lastReviewed dates per card
    private func mergeLearningProgress(cloud: NSUbiquitousKeyValueStore) {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        let localData = local.data(forKey: LearningModel.storageKey)
        let cloudData = cloud.object(forKey: LearningModel.storageKey) as? Data
        let localProgress = decodeLearningProgress(from: localData, using: decoder)
        let cloudProgress = decodeLearningProgress(from: cloudData, using: decoder)

        // Merge: for each card, keep the version with the more recent lastReviewed date
        var merged = localProgress
        for (cardId, cloudCard) in cloudProgress {
            if let localCard = merged[cardId] {
                // Compare lastReviewed dates — more recent wins
                let localDate = localCard.lastReviewed ?? .distantPast
                let cloudDate = cloudCard.lastReviewed ?? .distantPast
                if cloudDate > localDate {
                    merged[cardId] = cloudCard
                }
            } else {
                // Card only exists in cloud — add it
                merged[cardId] = cloudCard
            }
        }

        // Save merged result to both stores
        if let data = try? encoder.encode(merged) {
            local.set(data, forKey: LearningModel.storageKey)
            cloud.set(data, forKey: LearningModel.storageKey)
        }
    }

    private func decodeLearningProgress(
        from data: Data?,
        using decoder: JSONDecoder
    ) -> [String: CardProgress] {
        guard let data = data,
              let progress = try? decoder.decode([String: CardProgress].self, from: data)
        else { return [:] }
        return progress
    }
}

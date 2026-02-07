//
//  KeyValueStore.swift
//  ThaiSheet
//

import Foundation

/// Protocol abstracting the shared API surface of UserDefaults and NSUbiquitousKeyValueStore
protocol KeyValueStore {
    func set(_ value: Any?, forKey key: String)
    func set(_ value: Bool, forKey key: String)
    func object(forKey key: String) -> Any?
    func string(forKey key: String) -> String?
    func data(forKey key: String) -> Data?
    func removeObject(forKey key: String)
    @discardableResult func synchronize() -> Bool
}

// MARK: - UserDefaults Conformance

extension UserDefaults: KeyValueStore {}

// Note: NSUbiquitousKeyValueStore does not conform to KeyValueStore.
// SyncedKeyValueStore uses it directly via its native API.

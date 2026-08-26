//
//  ProgressIDMigration.swift
//  ThaiSheet
//

import Foundation

/// Re-keys persisted SRS progress from the content-derived IDs shipped versions
/// wrote to the durable IDs in use now (issue #29).
///
/// The map is the frozen `LegacyProgressIDs` table, so migration does not depend
/// on current content and needs no catalog: nothing is loaded, decoded, or
/// constructed to run it.
///
/// It is applied wherever a progress blob is decoded — local
/// (`LearningModel.load`) and iCloud (`SyncedKeyValueStore` reconciliation) — so
/// a blob written by an older client is normalized before it is merged, and the
/// normalized form is what gets persisted.
enum ProgressIDMigration {

    /// The default map: every historical key up to v1.2.
    static let bundled: [String: String] = LegacyProgressIDs.upToV1_2

    /// Re-keys a progress dictionary from legacy to durable IDs.
    ///
    /// - Idempotent: durable keys, and keys absent from the map, pass through
    ///   untouched, so re-running on an already-migrated blob changes nothing.
    /// - Lossless: nothing is dropped. An unrecognized key is kept as it is
    ///   rather than deleted, so progress written by a newer or unknown build
    ///   survives a round-trip through this one.
    /// - Ambiguity-safe: when a legacy entry and an already-durable entry land
    ///   on the same durable key, the most recently reviewed one wins — the same
    ///   policy the iCloud merge uses.
    static func migrate(
        _ progress: [String: CardProgress],
        using map: [String: String] = bundled
    ) -> [String: CardProgress] {
        guard !map.isEmpty, progress.keys.contains(where: { map[$0] != nil }) else {
            return progress
        }

        var result: [String: CardProgress] = [:]
        result.reserveCapacity(progress.count)
        for (key, value) in progress {
            let durableKey = map[key] ?? key
            let migrated = value.cardId == durableKey ? value : value.renamed(to: durableKey)
            guard let existing = result[durableKey] else {
                result[durableKey] = migrated
                continue
            }
            if (migrated.lastReviewed ?? .distantPast) > (existing.lastReviewed ?? .distantPast) {
                result[durableKey] = migrated
            }
        }
        return result
    }

    /// Whether migrating this blob would change its keys — the signal callers
    /// use to decide whether the normalized form needs persisting.
    static func needsMigration(
        _ progress: [String: CardProgress],
        using map: [String: String] = bundled
    ) -> Bool {
        progress.keys.contains { map[$0] != nil }
    }
}

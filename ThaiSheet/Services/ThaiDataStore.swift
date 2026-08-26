//
//  ThaiDataStore.swift
//  ThaiSheet
//

import SwiftUI

/// All bundled cheatsheet data, loaded once and shared by the Reference
/// browser and the flashcard system via the environment.
/// One bundled catalog. Datasets fail independently, which is what lets the
/// Reference tab keep working section by section.
enum ThaiDataset: String, CaseIterable {
    case consonants
    case vowels
    case toneMarks
    case toneRules
    case clusters
}

final class ThaiDataStore {
    let consonants: [Consonant]
    let vowels: [Vowel]
    let vowelCards: [VowelCard]
    let toneMarks: [ToneMark]
    let toneMarkCards: [ToneMarkCard]
    let toneRules: [ToneRule]
    let toneRuleCards: [ToneRuleCard]
    let clusters: [Cluster]

    /// Why each failed dataset failed. Empty when everything loaded.
    let failures: [ThaiDataset: DatasetLoadError]

    init(provider: ResourceProviding = BundleResourceProvider()) {
        var failures: [ThaiDataset: DatasetLoadError] = [:]

        func rows<T>(_ dataset: ThaiDataset, _ result: Result<[T], DatasetLoadError>) -> [T] {
            switch result {
            case .success(let items):
                return items
            case .failure(let error):
                failures[dataset] = error
                return []
            }
        }

        consonants = rows(.consonants, Consonant.loadAll(provider: provider))
        vowels = rows(.vowels, Vowel.loadAll(provider: provider))
        vowelCards = VowelCard.allCards(from: vowels)
        toneMarks = rows(.toneMarks, ToneMark.loadAll(provider: provider))
        toneMarkCards = ToneMarkCard.allCards(from: toneMarks)
        toneRules = rows(.toneRules, ToneRule.loadAll(provider: provider))
        toneRuleCards = ToneRuleCard.allCards(from: toneRules)
        clusters = rows(.clusters, Cluster.loadAll(provider: provider))

        self.failures = failures
    }

    /// Outcome of bundle loading. Loading is synchronous in `init`, so by the
    /// time a store exists the outcome is final: there is no runtime "still
    /// loading" phase to represent, and an unavailable dataset is a terminal
    /// packaging failure rather than a wait.
    enum LoadState: Equatable {
        case loaded
        /// At least one dataset failed. Ordered by `ThaiDataset.allCases` so the
        /// value is stable to compare and to log.
        case failed(errors: [DatasetLoadError])
    }

    var loadState: LoadState {
        let errors = ThaiDataset.allCases.compactMap { failures[$0] }
        return errors.isEmpty ? .loaded : .failed(errors: errors)
    }

    /// Whether a single dataset is usable, so one failed catalog does not take
    /// the rest of the Reference tab down with it.
    func isAvailable(_ dataset: ThaiDataset) -> Bool {
        failures[dataset] == nil
    }

    /// Whether every dataset a section needs is usable.
    func isAvailable(_ datasets: [ThaiDataset]) -> Bool {
        datasets.allSatisfy(isAvailable)
    }

    var isLoaded: Bool {
        loadState == .loaded
    }
}

// MARK: - Voice override resolution

/// The persisted identity of a per-item voice override (what Settings lists and
/// what `voiceOverrides` keys on).
struct VoiceOverrideDescriptor {
    let id: String
    /// Stable English group key ("Consonants"/"Vowels"/"Clusters"/"Tones"),
    /// localized for display by the view.
    let group: String
    let display: String
}

/// The exact clip to audition / availability-check (distinct granularity from the
/// descriptor — a vowel row has one override but form-specific playback words).
struct VoicePreviewTarget {
    let soundType: SoundType
    let playbackKey: String
}

/// Bundles the identity with a canonical preview so the resolver API is unambiguous.
struct VoiceOverrideCatalogEntry {
    let descriptor: VoiceOverrideDescriptor
    let canonicalPreview: VoicePreviewTarget
}

extension ThaiDataStore {
    /// Resolve a persisted override id back to its item (for Settings display + a
    /// canonical preview). Returns nil for a stale id whose item no longer exists.
    func voiceOverrideCatalogEntry(for id: String) -> VoiceOverrideCatalogEntry? {
        guard let (type, key) = Self.splitOverrideID(id) else { return nil }
        func entry(_ group: String, _ display: String, _ preview: VoicePreviewTarget) -> VoiceOverrideCatalogEntry {
            VoiceOverrideCatalogEntry(
                descriptor: VoiceOverrideDescriptor(id: id, group: group, display: display),
                canonicalPreview: preview
            )
        }
        switch type {
        case .consonant:
            guard let c = consonants.first(where: { $0.id == key }) else { return nil }
            return entry("Consonants", "\(c.character) · \(c.transcription)",
                         VoicePreviewTarget(soundType: .consonant, playbackKey: c.character))
        case .vowel:
            guard let v = vowels.first(where: { $0.id == key }),
                  let word = Self.representativeVowelWord(v) else { return nil }
            return entry("Vowels", v.sound,
                         VoicePreviewTarget(soundType: .vowel, playbackKey: word))
        case .cluster:
            guard let cl = clusters.first(where: { $0.id == key }) else { return nil }
            return entry("Clusters", cl.cluster,
                         VoicePreviewTarget(soundType: .cluster, playbackKey: cl.audioKey))
        case .toneMark:
            // The override id keys on the class-entry soundKey (also the playback key).
            guard let e = toneMarks.flatMap({ $0.classEntries }).first(where: { $0.soundKey == key }) else { return nil }
            return entry("Tones", e.display,
                         VoicePreviewTarget(soundType: .toneMark, playbackKey: key))
        case .toneRule:
            guard let r = toneRules.first(where: { $0.id == key }), let sample = r.primarySample else { return nil }
            return entry("Tones", sample.full,
                         VoicePreviewTarget(soundType: .toneRule, playbackKey: sample.full))
        }
    }

    /// Deterministic preview word for a vowel row (mirrors the row's form priority).
    private static func representativeVowelWord(_ v: Vowel) -> String? {
        let order: [(String, String)] = [("Long", "Closed"), ("Short", "Closed"), ("Long", "Open"), ("Short", "Open")]
        return order.lazy.compactMap { v.pronunciation(for: $0.0, form: $0.1)?.word }.first
    }

    /// Split `"<idPrefix>-<key>"` into its `FlashcardType` and key.
    static func splitOverrideID(_ id: String) -> (FlashcardType, String)? {
        for type in [FlashcardType.consonant, .vowel, .toneMark, .toneRule, .cluster] {
            let prefix = type.idPrefix + "-"
            if id.hasPrefix(prefix) { return (type, String(id.dropFirst(prefix.count))) }
        }
        return nil
    }
}

// MARK: - Environment Key

private struct ThaiDataStoreKey: EnvironmentKey {
    static let defaultValue = ThaiDataStore()
}

extension EnvironmentValues {
    var thaiData: ThaiDataStore {
        get { self[ThaiDataStoreKey.self] }
        set { self[ThaiDataStoreKey.self] = newValue }
    }
}

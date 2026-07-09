//
//  FlashcardSettings.swift
//  ThaiSheet
//

import Foundation
import SwiftUI

@Observable
class FlashcardSettings {
    private let defaults: KeyValueStore

    /// All keys persisted by this class, in one place so sync code
    /// (SyncedKeyValueStore.pushAllToCloud) stays in step automatically.
    static let syncedKeys: [String] = [
        "fc_consonantsEnabled", "fc_vowelsEnabled", "fc_tonesEnabled", "fc_clusters",
        "fc_highConsonants", "fc_midConsonants", "fc_lowConsonants", "fc_uncommonConsonants",
        "fc_longVowels", "fc_shortVowels", "fc_uncommonVowels",
        "fc_highToneRules", "fc_midToneRules", "fc_lowToneRules", "fc_toneMarks",
        "fc_smoothClusters", "fc_silentClusters", "fc_irregularClusters",
        "fc_useIntelligentSelection", "fc_appLanguage", "fc_iCloudSyncEnabled",
    ]

    // Inline values are placeholders overwritten by reload() in init;
    // the canonical defaults are the ?? fallbacks in reload().

    // MARK: - Parent Category Toggles

    var consonantsEnabled = true {
        didSet { persist(consonantsEnabled, forKey: "fc_consonantsEnabled") }
    }

    var vowelsEnabled = true {
        didSet { persist(vowelsEnabled, forKey: "fc_vowelsEnabled") }
    }

    var tonesEnabled = true {
        didSet { persist(tonesEnabled, forKey: "fc_tonesEnabled") }
    }

    var clusters = true {
        didSet { persist(clusters, forKey: "fc_clusters") }
    }

    // MARK: - Consonant Filters

    var highConsonants = true {
        didSet { persist(highConsonants, forKey: "fc_highConsonants") }
    }

    var midConsonants = true {
        didSet { persist(midConsonants, forKey: "fc_midConsonants") }
    }

    var lowConsonants = true {
        didSet { persist(lowConsonants, forKey: "fc_lowConsonants") }
    }

    var uncommonConsonants = true {
        didSet { persist(uncommonConsonants, forKey: "fc_uncommonConsonants") }
    }

    // MARK: - Vowel Filters

    var longVowels = true {
        didSet { persist(longVowels, forKey: "fc_longVowels") }
    }

    var shortVowels = true {
        didSet { persist(shortVowels, forKey: "fc_shortVowels") }
    }

    var uncommonVowels = true {
        didSet { persist(uncommonVowels, forKey: "fc_uncommonVowels") }
    }

    // MARK: - Tone Filters

    var highToneRules = true {
        didSet { persist(highToneRules, forKey: "fc_highToneRules") }
    }

    var midToneRules = true {
        didSet { persist(midToneRules, forKey: "fc_midToneRules") }
    }

    var lowToneRules = true {
        didSet { persist(lowToneRules, forKey: "fc_lowToneRules") }
    }

    var toneMarks = true {
        didSet { persist(toneMarks, forKey: "fc_toneMarks") }
    }

    // MARK: - Cluster Filters

    var smoothClusters = true {
        didSet { persist(smoothClusters, forKey: "fc_smoothClusters") }
    }

    var silentClusters = true {
        didSet { persist(silentClusters, forKey: "fc_silentClusters") }
    }

    var irregularClusters = true {
        didSet { persist(irregularClusters, forKey: "fc_irregularClusters") }
    }

    // MARK: - Other Settings

    var useIntelligentSelection = false {
        didSet { persist(useIntelligentSelection, forKey: "fc_useIntelligentSelection") }
    }

    var appLanguage = "system" {
        didSet { persist(appLanguage, forKey: "fc_appLanguage") }
    }

    /// Supported languages for the in-app picker
    static let supportedLanguages: [(code: String, name: String)] = [
        ("system", "System"),
        ("en", "English"),
        ("fr", "Français"),
    ]

    /// Resolved locale based on the app language setting
    var resolvedLocale: Locale {
        if appLanguage == "system" {
            return .current
        }
        return Locale(identifier: appLanguage)
    }

    var iCloudSyncEnabled = false {
        didSet { persist(iCloudSyncEnabled, forKey: "fc_iCloudSyncEnabled") }
    }

    // MARK: - Initialization

    init(defaults: KeyValueStore = UserDefaults.standard) {
        self.defaults = defaults
        // Load without persisting: reading a default must not write it back
        // (unset keys stay unset so future default changes still apply).
        suppressPersistence = true
        reload()
        suppressPersistence = false
    }

    // MARK: - Persistence

    @ObservationIgnored private var suppressPersistence = false

    private func persist(_ value: Any?, forKey key: String) {
        guard !suppressPersistence else { return }
        defaults.set(value, forKey: key)
    }

    /// Reload all settings from the store (called when external sync updates arrive)
    func reload() {
        consonantsEnabled = defaults.object(forKey: "fc_consonantsEnabled") as? Bool ?? true
        vowelsEnabled = defaults.object(forKey: "fc_vowelsEnabled") as? Bool ?? true
        tonesEnabled = defaults.object(forKey: "fc_tonesEnabled") as? Bool ?? true
        clusters = defaults.object(forKey: "fc_clusters") as? Bool ?? true

        highConsonants = defaults.object(forKey: "fc_highConsonants") as? Bool ?? true
        midConsonants = defaults.object(forKey: "fc_midConsonants") as? Bool ?? true
        lowConsonants = defaults.object(forKey: "fc_lowConsonants") as? Bool ?? true
        uncommonConsonants = defaults.object(forKey: "fc_uncommonConsonants") as? Bool ?? true

        longVowels = defaults.object(forKey: "fc_longVowels") as? Bool ?? true
        shortVowels = defaults.object(forKey: "fc_shortVowels") as? Bool ?? true
        uncommonVowels = defaults.object(forKey: "fc_uncommonVowels") as? Bool ?? true

        highToneRules = defaults.object(forKey: "fc_highToneRules") as? Bool ?? true
        midToneRules = defaults.object(forKey: "fc_midToneRules") as? Bool ?? true
        lowToneRules = defaults.object(forKey: "fc_lowToneRules") as? Bool ?? true
        toneMarks = defaults.object(forKey: "fc_toneMarks") as? Bool ?? true

        smoothClusters = defaults.object(forKey: "fc_smoothClusters") as? Bool ?? true
        silentClusters = defaults.object(forKey: "fc_silentClusters") as? Bool ?? true
        irregularClusters = defaults.object(forKey: "fc_irregularClusters") as? Bool ?? true

        useIntelligentSelection = defaults.object(forKey: "fc_useIntelligentSelection") as? Bool ?? false
        appLanguage = defaults.string(forKey: "fc_appLanguage") ?? "system"
        iCloudSyncEnabled = defaults.object(forKey: "fc_iCloudSyncEnabled") as? Bool ?? false
    }

    // MARK: - Filter Counts

    var enabledVowelFilterCount: Int {
        var count = 0
        if longVowels { count += 1 }
        if shortVowels { count += 1 }
        if uncommonVowels { count += 1 }
        return count
    }

    // MARK: - Filter Functions

    func isConsonantEnabled(_ consonant: Consonant) -> Bool {
        guard consonantsEnabled else { return false }

        // Class-based filters apply to COMMON consonants
        if consonant.usage == .common {
            switch consonant.consonantClass {
            case .high:
                if highConsonants { return true }
            case .mid:
                if midConsonants { return true }
            case .low:
                if lowConsonants { return true }
            }
        }

        // Uncommon/rare/ancient filter applies regardless of class
        if consonant.usage != .common && uncommonConsonants {
            return true
        }

        return false
    }

    func isVowelCardEnabled(duration: VowelCard.VowelDuration, isUncommon: Bool) -> Bool {
        guard vowelsEnabled else { return false }

        // Check usage filter first - uncommon vowels need the toggle enabled
        if isUncommon && !uncommonVowels {
            return false
        }

        // Then check duration filter
        switch duration {
        case .long: return longVowels
        case .short: return shortVowels
        }
    }

    func isToneRuleEnabled(initialConsonant: String) -> Bool {
        guard tonesEnabled else { return false }
        switch initialConsonant {
        case "High": return highToneRules
        case "Mid": return midToneRules
        case "Low": return lowToneRules
        default: return false
        }
    }

    var areToneMarksEnabled: Bool {
        tonesEnabled && toneMarks
    }

    func isClusterEnabled(_ cluster: Cluster) -> Bool {
        guard clusters else { return false }
        switch cluster.type {
        case .smooth: return smoothClusters
        case .silent: return silentClusters
        case .irregular: return irregularClusters
        }
    }

    // MARK: - Bulk Actions

    func selectAll() {
        // Parents
        consonantsEnabled = true
        vowelsEnabled = true
        tonesEnabled = true
        clusters = true

        // Consonants
        highConsonants = true
        midConsonants = true
        lowConsonants = true
        uncommonConsonants = true

        // Vowels
        longVowels = true
        shortVowels = true
        uncommonVowels = true

        // Tones
        highToneRules = true
        midToneRules = true
        lowToneRules = true
        toneMarks = true

        // Clusters
        smoothClusters = true
        silentClusters = true
        irregularClusters = true
    }

    func deselectAll() {
        // Parents
        consonantsEnabled = false
        vowelsEnabled = false
        tonesEnabled = false
        clusters = false

        // Consonants
        highConsonants = false
        midConsonants = false
        lowConsonants = false
        uncommonConsonants = false

        // Vowels
        longVowels = false
        shortVowels = false
        uncommonVowels = false

        // Tones
        highToneRules = false
        midToneRules = false
        lowToneRules = false
        toneMarks = false

        // Clusters
        smoothClusters = false
        silentClusters = false
        irregularClusters = false
    }

    var isAllSelected: Bool {
        consonantsEnabled && vowelsEnabled && tonesEnabled && clusters &&
        highConsonants && midConsonants && lowConsonants && uncommonConsonants &&
        longVowels && shortVowels && uncommonVowels &&
        highToneRules && midToneRules && lowToneRules && toneMarks &&
        smoothClusters && silentClusters && irregularClusters
    }

    var isNoneSelected: Bool {
        !consonantsEnabled && !vowelsEnabled && !tonesEnabled && !clusters
    }

    // MARK: - Partial Testing Detection

    func isPartialTesting(for cardType: FlashcardType) -> Bool {
        switch cardType {
        case .consonant:
            // Class question is trivial if only one consonant class is enabled
            return enabledConsonantClassCount == 1

        case .vowel:
            // Duration question is trivial if only one duration is enabled
            return enabledVowelFilterCount == 1

        case .toneMark:
            return false

        case .toneRule:
            return enabledToneRuleClassCount == 1

        case .cluster:
            return false
        }
    }

    /// Count of enabled consonant classes (high/mid/low, excluding uncommon)
    private var enabledConsonantClassCount: Int {
        var count = 0
        if highConsonants { count += 1 }
        if midConsonants { count += 1 }
        if lowConsonants { count += 1 }
        return count
    }

    /// Count of enabled tone rule consonant classes
    private var enabledToneRuleClassCount: Int {
        var count = 0
        if highToneRules { count += 1 }
        if midToneRules { count += 1 }
        if lowToneRules { count += 1 }
        return count
    }
}

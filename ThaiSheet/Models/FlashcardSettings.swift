//
//  FlashcardSettings.swift
//  ThaiSheet
//

import Foundation
import SwiftUI

@Observable
class FlashcardSettings {
    private let defaults: UserDefaults

    // MARK: - Parent Category Toggles

    var consonantsEnabled: Bool {
        didSet { defaults.set(consonantsEnabled, forKey: "fc_consonantsEnabled") }
    }

    var vowelsEnabled: Bool {
        didSet { defaults.set(vowelsEnabled, forKey: "fc_vowelsEnabled") }
    }

    var tonesEnabled: Bool {
        didSet { defaults.set(tonesEnabled, forKey: "fc_tonesEnabled") }
    }

    var clusters: Bool {
        didSet { defaults.set(clusters, forKey: "fc_clusters") }
    }

    // MARK: - Consonant Filters

    var highConsonants: Bool {
        didSet { defaults.set(highConsonants, forKey: "fc_highConsonants") }
    }

    var midConsonants: Bool {
        didSet { defaults.set(midConsonants, forKey: "fc_midConsonants") }
    }

    var lowConsonants: Bool {
        didSet { defaults.set(lowConsonants, forKey: "fc_lowConsonants") }
    }

    var uncommonConsonants: Bool {
        didSet { defaults.set(uncommonConsonants, forKey: "fc_uncommonConsonants") }
    }

    // MARK: - Vowel Filters

    var longVowels: Bool {
        didSet { defaults.set(longVowels, forKey: "fc_longVowels") }
    }

    var shortVowels: Bool {
        didSet { defaults.set(shortVowels, forKey: "fc_shortVowels") }
    }

    var uncommonVowels: Bool {
        didSet { defaults.set(uncommonVowels, forKey: "fc_uncommonVowels") }
    }

    // MARK: - Tone Filters

    var highToneRules: Bool {
        didSet { defaults.set(highToneRules, forKey: "fc_highToneRules") }
    }

    var midToneRules: Bool {
        didSet { defaults.set(midToneRules, forKey: "fc_midToneRules") }
    }

    var lowToneRules: Bool {
        didSet { defaults.set(lowToneRules, forKey: "fc_lowToneRules") }
    }

    var toneMarks: Bool {
        didSet { defaults.set(toneMarks, forKey: "fc_toneMarks") }
    }

    // MARK: - Cluster Filters

    var smoothClusters: Bool {
        didSet { defaults.set(smoothClusters, forKey: "fc_smoothClusters") }
    }

    var silentClusters: Bool {
        didSet { defaults.set(silentClusters, forKey: "fc_silentClusters") }
    }

    var irregularClusters: Bool {
        didSet { defaults.set(irregularClusters, forKey: "fc_irregularClusters") }
    }

    // MARK: - Other Settings

    var useIntelligentSelection: Bool {
        didSet { defaults.set(useIntelligentSelection, forKey: "fc_useIntelligentSelection") }
    }

    var appLanguage: String {
        didSet { defaults.set(appLanguage, forKey: "fc_appLanguage") }
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

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Parent toggles - all enabled by default
        self.consonantsEnabled = defaults.object(forKey: "fc_consonantsEnabled") as? Bool ?? true
        self.vowelsEnabled = defaults.object(forKey: "fc_vowelsEnabled") as? Bool ?? true
        self.tonesEnabled = defaults.object(forKey: "fc_tonesEnabled") as? Bool ?? true
        self.clusters = defaults.object(forKey: "fc_clusters") as? Bool ?? true

        // Consonant filters - all enabled by default
        self.highConsonants = defaults.object(forKey: "fc_highConsonants") as? Bool ?? true
        self.midConsonants = defaults.object(forKey: "fc_midConsonants") as? Bool ?? true
        self.lowConsonants = defaults.object(forKey: "fc_lowConsonants") as? Bool ?? true
        self.uncommonConsonants = defaults.object(forKey: "fc_uncommonConsonants") as? Bool ?? true

        // Vowel filters
        self.longVowels = defaults.object(forKey: "fc_longVowels") as? Bool ?? true
        self.shortVowels = defaults.object(forKey: "fc_shortVowels") as? Bool ?? true
        self.uncommonVowels = defaults.object(forKey: "fc_uncommonVowels") as? Bool ?? true

        // Tone filters
        self.highToneRules = defaults.object(forKey: "fc_highToneRules") as? Bool ?? true
        self.midToneRules = defaults.object(forKey: "fc_midToneRules") as? Bool ?? true
        self.lowToneRules = defaults.object(forKey: "fc_lowToneRules") as? Bool ?? true
        self.toneMarks = defaults.object(forKey: "fc_toneMarks") as? Bool ?? true

        // Cluster filters
        self.smoothClusters = defaults.object(forKey: "fc_smoothClusters") as? Bool ?? true
        self.silentClusters = defaults.object(forKey: "fc_silentClusters") as? Bool ?? true
        self.irregularClusters = defaults.object(forKey: "fc_irregularClusters") as? Bool ?? true

        // Other
        self.useIntelligentSelection = defaults.object(forKey: "fc_useIntelligentSelection") as? Bool ?? false
        self.appLanguage = defaults.string(forKey: "fc_appLanguage") ?? "system"
    }

    // MARK: - Filter Counts

    var enabledConsonantFilterCount: Int {
        var count = 0
        if highConsonants { count += 1 }
        if midConsonants { count += 1 }
        if lowConsonants { count += 1 }
        if uncommonConsonants { count += 1 }
        return count
    }

    var enabledVowelFilterCount: Int {
        var count = 0
        if longVowels { count += 1 }
        if shortVowels { count += 1 }
        if uncommonVowels { count += 1 }
        return count
    }

    var enabledToneFilterCount: Int {
        var count = 0
        if highToneRules { count += 1 }
        if midToneRules { count += 1 }
        if lowToneRules { count += 1 }
        if toneMarks { count += 1 }
        return count
    }

    var enabledClusterTypeCount: Int {
        var count = 0
        if smoothClusters { count += 1 }
        if silentClusters { count += 1 }
        if irregularClusters { count += 1 }
        return count
    }

    // MARK: - Category State Helpers

    /// Count of enabled parent categories
    var enabledCategoryCount: Int {
        var count = 0
        if consonantsEnabled { count += 1 }
        if vowelsEnabled { count += 1 }
        if tonesEnabled { count += 1 }
        if clusters { count += 1 }
        return count
    }

    var isOnlyConsonantsEnabled: Bool {
        consonantsEnabled && !vowelsEnabled && !tonesEnabled && !clusters
    }

    var isOnlyVowelsEnabled: Bool {
        !consonantsEnabled && vowelsEnabled && !tonesEnabled && !clusters
    }

    var isOnlyTonesEnabled: Bool {
        !consonantsEnabled && !vowelsEnabled && tonesEnabled && !clusters
    }

    var isOnlyClustersEnabled: Bool {
        !consonantsEnabled && !vowelsEnabled && !tonesEnabled && clusters
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

    // MARK: - Legacy Compatibility

    var hasAnyConsonantEnabled: Bool {
        consonantsEnabled && enabledConsonantFilterCount > 0
    }

    var hasAnyVowelEnabled: Bool {
        vowelsEnabled && enabledVowelFilterCount > 0
    }

    var hasAnyToneRuleEnabled: Bool {
        tonesEnabled && (highToneRules || midToneRules || lowToneRules)
    }

    var areClustersEnabled: Bool {
        clusters && enabledClusterTypeCount > 0
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

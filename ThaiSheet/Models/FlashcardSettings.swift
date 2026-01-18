//
//  FlashcardSettings.swift
//  ThaiSheet
//

import Foundation
import SwiftUI

@Observable
class FlashcardSettings {
    private let defaults = UserDefaults.standard

    // Consonants - stored properties for proper @Observable support
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

    // Vowels
    var longVowels: Bool {
        didSet { defaults.set(longVowels, forKey: "fc_longVowels") }
    }

    var shortVowels: Bool {
        didSet { defaults.set(shortVowels, forKey: "fc_shortVowels") }
    }

    // Tones
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

    // Clusters
    var clusters: Bool {
        didSet { defaults.set(clusters, forKey: "fc_clusters") }
    }

    // Selection mode
    var useIntelligentSelection: Bool {
        didSet { defaults.set(useIntelligentSelection, forKey: "fc_useIntelligentSelection") }
    }

    init() {
        // Load persisted values from UserDefaults
        self.highConsonants = UserDefaults.standard.object(forKey: "fc_highConsonants") as? Bool ?? true
        self.midConsonants = UserDefaults.standard.object(forKey: "fc_midConsonants") as? Bool ?? false
        self.lowConsonants = UserDefaults.standard.object(forKey: "fc_lowConsonants") as? Bool ?? false
        self.uncommonConsonants = UserDefaults.standard.object(forKey: "fc_uncommonConsonants") as? Bool ?? false
        self.longVowels = UserDefaults.standard.object(forKey: "fc_longVowels") as? Bool ?? false
        self.shortVowels = UserDefaults.standard.object(forKey: "fc_shortVowels") as? Bool ?? false
        self.highToneRules = UserDefaults.standard.object(forKey: "fc_highToneRules") as? Bool ?? false
        self.midToneRules = UserDefaults.standard.object(forKey: "fc_midToneRules") as? Bool ?? false
        self.lowToneRules = UserDefaults.standard.object(forKey: "fc_lowToneRules") as? Bool ?? false
        self.toneMarks = UserDefaults.standard.object(forKey: "fc_toneMarks") as? Bool ?? false
        self.clusters = UserDefaults.standard.object(forKey: "fc_clusters") as? Bool ?? false
        self.useIntelligentSelection = UserDefaults.standard.object(forKey: "fc_useIntelligentSelection") as? Bool ?? false
    }

    // Count of enabled options
    var enabledCount: Int {
        var count = 0
        if highConsonants { count += 1 }
        if midConsonants { count += 1 }
        if lowConsonants { count += 1 }
        if uncommonConsonants { count += 1 }
        if longVowels { count += 1 }
        if shortVowels { count += 1 }
        if highToneRules { count += 1 }
        if midToneRules { count += 1 }
        if lowToneRules { count += 1 }
        if toneMarks { count += 1 }
        if clusters { count += 1 }
        return count
    }

    // At least one must be enabled
    var isLastEnabled: Bool {
        enabledCount == 1
    }

    // MARK: - Filter Functions

    func isConsonantEnabled(_ consonant: Consonant) -> Bool {
        // OR-based opt-in: include if ANY matching criterion is enabled

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

    var hasAnyConsonantEnabled: Bool {
        highConsonants || midConsonants || lowConsonants || uncommonConsonants
    }

    var hasAnyVowelEnabled: Bool {
        longVowels || shortVowels
    }

    var hasAnyToneRuleEnabled: Bool {
        highToneRules || midToneRules || lowToneRules
    }

    var areToneMarksEnabled: Bool {
        toneMarks
    }

    // MARK: - Bulk Actions

    func selectAll() {
        highConsonants = true
        midConsonants = true
        lowConsonants = true
        uncommonConsonants = true
        longVowels = true
        shortVowels = true
        highToneRules = true
        midToneRules = true
        lowToneRules = true
        toneMarks = true
        clusters = true
    }

    func resetToDefault() {
        highConsonants = true
        midConsonants = false
        lowConsonants = false
        uncommonConsonants = false
        longVowels = false
        shortVowels = false
        highToneRules = false
        midToneRules = false
        lowToneRules = false
        toneMarks = false
        clusters = false
    }

    var isAllSelected: Bool {
        highConsonants && midConsonants && lowConsonants && uncommonConsonants &&
        longVowels && shortVowels &&
        highToneRules && midToneRules && lowToneRules && toneMarks && clusters
    }

    var isDefault: Bool {
        highConsonants && !midConsonants && !lowConsonants && !uncommonConsonants &&
        !longVowels && !shortVowels &&
        !highToneRules && !midToneRules && !lowToneRules && !toneMarks && !clusters
    }

    var areClustersEnabled: Bool {
        clusters
    }

    // MARK: - Partial Testing Detection

    /// Returns true if the current filters make any questions trivial for this card type.
    /// Used to determine if SRS advancement should be capped.
    func isPartialTesting(for cardType: FlashcardType) -> Bool {
        switch cardType {
        case .consonant:
            // Class question is trivial if only one consonant class is enabled
            return enabledConsonantClassCount == 1

        case .vowel:
            // Duration question is trivial if only one duration is enabled
            return enabledVowelDurationCount == 1

        case .toneMark:
            // ToneMark cards always test class (Low vs Mid/High) - not affected by consonant filters
            // since the cards use their own random consonants
            return false

        case .toneRule:
            // Consonant class question is trivial if only one class is enabled
            return enabledToneRuleClassCount == 1

        case .cluster:
            // Cluster questions always test type and sound - not affected by filters
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

    /// Count of enabled vowel durations
    private var enabledVowelDurationCount: Int {
        var count = 0
        if longVowels { count += 1 }
        if shortVowels { count += 1 }
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

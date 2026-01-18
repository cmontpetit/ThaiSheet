//
//  FlashcardSettings.swift
//  ThaiSheet
//

import Foundation
import SwiftUI

@Observable
class FlashcardSettings {
    // Use UserDefaults directly with manual observation
    private let defaults = UserDefaults.standard

    // Consonants
    var highConsonants: Bool {
        get { defaults.object(forKey: "fc_highConsonants") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "fc_highConsonants") }
    }

    var midConsonants: Bool {
        get { defaults.object(forKey: "fc_midConsonants") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "fc_midConsonants") }
    }

    var lowConsonants: Bool {
        get { defaults.object(forKey: "fc_lowConsonants") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "fc_lowConsonants") }
    }

    var uncommonConsonants: Bool {
        get { defaults.object(forKey: "fc_uncommonConsonants") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "fc_uncommonConsonants") }
    }

    // Vowels
    var longVowels: Bool {
        get { defaults.object(forKey: "fc_longVowels") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "fc_longVowels") }
    }

    var shortVowels: Bool {
        get { defaults.object(forKey: "fc_shortVowels") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "fc_shortVowels") }
    }

    // Tones
    var highToneRules: Bool {
        get { defaults.object(forKey: "fc_highToneRules") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "fc_highToneRules") }
    }

    var midToneRules: Bool {
        get { defaults.object(forKey: "fc_midToneRules") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "fc_midToneRules") }
    }

    var lowToneRules: Bool {
        get { defaults.object(forKey: "fc_lowToneRules") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "fc_lowToneRules") }
    }

    var toneMarks: Bool {
        get { defaults.object(forKey: "fc_toneMarks") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "fc_toneMarks") }
    }

    // Selection mode - uses stored property for proper @Observable support
    var useIntelligentSelection: Bool {
        didSet { defaults.set(useIntelligentSelection, forKey: "fc_useIntelligentSelection") }
    }

    init() {
        // Load persisted value
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
    }

    var isAllSelected: Bool {
        highConsonants && midConsonants && lowConsonants && uncommonConsonants &&
        longVowels && shortVowels &&
        highToneRules && midToneRules && lowToneRules && toneMarks
    }

    var isDefault: Bool {
        highConsonants && !midConsonants && !lowConsonants && !uncommonConsonants &&
        !longVowels && !shortVowels &&
        !highToneRules && !midToneRules && !lowToneRules && !toneMarks
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

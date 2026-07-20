//
//  FlashcardSettingsTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

@MainActor
final class FlashcardSettingsTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settings: FlashcardSettings!

    override func setUp() {
        super.setUp()
        suiteName = "FlashcardSettingsTests_\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settings = FlashcardSettings(defaults: defaults)
    }

    override func tearDown() {
        settings = nil
        defaults = nil
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Defaults

    func test_defaults_allCategoryTogglesTrue() {
        XCTAssertTrue(settings.consonantsEnabled)
        XCTAssertTrue(settings.vowelsEnabled)
        XCTAssertTrue(settings.tonesEnabled)
        XCTAssertTrue(settings.clusters)
    }

    func test_defaults_allConsonantFiltersTrue() {
        XCTAssertTrue(settings.highConsonants)
        XCTAssertTrue(settings.midConsonants)
        XCTAssertTrue(settings.lowConsonants)
        XCTAssertTrue(settings.uncommonConsonants)
    }

    func test_defaults_allVowelFiltersTrue() {
        XCTAssertTrue(settings.longVowels)
        XCTAssertTrue(settings.shortVowels)
        XCTAssertTrue(settings.uncommonVowels)
    }

    func test_defaults_allToneFiltersTrue() {
        XCTAssertTrue(settings.highToneRules)
        XCTAssertTrue(settings.midToneRules)
        XCTAssertTrue(settings.lowToneRules)
        XCTAssertTrue(settings.toneMarks)
    }

    func test_defaults_allClusterFiltersTrue() {
        XCTAssertTrue(settings.smoothClusters)
        XCTAssertTrue(settings.silentClusters)
        XCTAssertTrue(settings.irregularClusters)
    }

    func test_defaults_useIntelligentSelection_isFalse() {
        XCTAssertFalse(settings.useIntelligentSelection)
    }

    func test_defaults_appLanguage_isSystem() {
        XCTAssertEqual(settings.appLanguage, "system")
    }

    // MARK: - isConsonantEnabled

    func test_isConsonantEnabled_commonHighConsonant_enabledWhenHighTrue() {
        let consonants = Consonant.loadAll()
        // Find a common high class consonant
        guard let highConsonant = consonants.first(where: {
            $0.consonantClass == .high && $0.usage == .common
        }) else {
            XCTFail("No common high consonant found in data")
            return
        }

        settings.highConsonants = true
        XCTAssertTrue(settings.isConsonantEnabled(highConsonant))
    }

    func test_isConsonantEnabled_commonHighConsonant_disabledWhenHighFalse() {
        let consonants = Consonant.loadAll()
        guard let highConsonant = consonants.first(where: {
            $0.consonantClass == .high && $0.usage == .common
        }) else {
            XCTFail("No common high consonant found in data")
            return
        }

        settings.highConsonants = false
        XCTAssertFalse(settings.isConsonantEnabled(highConsonant))
    }

    func test_isConsonantEnabled_commonMidConsonant_enabledWhenMidTrue() {
        let consonants = Consonant.loadAll()
        guard let midConsonant = consonants.first(where: {
            $0.consonantClass == .mid && $0.usage == .common
        }) else {
            XCTFail("No common mid consonant found in data")
            return
        }

        settings.midConsonants = true
        XCTAssertTrue(settings.isConsonantEnabled(midConsonant))
    }

    func test_isConsonantEnabled_commonLowConsonant_enabledWhenLowTrue() {
        let consonants = Consonant.loadAll()
        guard let lowConsonant = consonants.first(where: {
            $0.consonantClass == .low && $0.usage == .common
        }) else {
            XCTFail("No common low consonant found in data")
            return
        }

        settings.lowConsonants = true
        XCTAssertTrue(settings.isConsonantEnabled(lowConsonant))
    }

    func test_isConsonantEnabled_uncommonConsonant_enabledOnlyWhenUncommonTrue() {
        let consonants = Consonant.loadAll()
        guard let uncommonConsonant = consonants.first(where: {
            $0.usage == .uncommon || $0.usage == .rare || $0.usage == .ancient
        }) else {
            XCTFail("No uncommon consonant found in data")
            return
        }

        settings.uncommonConsonants = true
        XCTAssertTrue(settings.isConsonantEnabled(uncommonConsonant))

        settings.uncommonConsonants = false
        XCTAssertFalse(settings.isConsonantEnabled(uncommonConsonant))
    }

    func test_isConsonantEnabled_disabledWhenConsonantsParentOff() {
        let consonants = Consonant.loadAll()
        let anyConsonant = consonants[0]

        settings.consonantsEnabled = false
        XCTAssertFalse(settings.isConsonantEnabled(anyConsonant))
    }

    // MARK: - isVowelCardEnabled

    func test_isVowelCardEnabled_longCommon_enabledWhenLongVowelsTrue() {
        XCTAssertTrue(settings.isVowelCardEnabled(duration: .long, isUncommon: false))
    }

    func test_isVowelCardEnabled_longCommon_disabledWhenLongVowelsFalse() {
        settings.longVowels = false
        XCTAssertFalse(settings.isVowelCardEnabled(duration: .long, isUncommon: false))
    }

    func test_isVowelCardEnabled_shortCommon_enabledWhenShortVowelsTrue() {
        XCTAssertTrue(settings.isVowelCardEnabled(duration: .short, isUncommon: false))
    }

    func test_isVowelCardEnabled_shortCommon_disabledWhenShortVowelsFalse() {
        settings.shortVowels = false
        XCTAssertFalse(settings.isVowelCardEnabled(duration: .short, isUncommon: false))
    }

    func test_isVowelCardEnabled_uncommonVowel_disabledWhenUncommonFalse() {
        settings.uncommonVowels = false
        XCTAssertFalse(settings.isVowelCardEnabled(duration: .long, isUncommon: true))
        XCTAssertFalse(settings.isVowelCardEnabled(duration: .short, isUncommon: true))
    }

    func test_isVowelCardEnabled_uncommonLong_needsBothToggles() {
        // Both uncommonVowels and longVowels must be true
        settings.uncommonVowels = true
        settings.longVowels = true
        XCTAssertTrue(settings.isVowelCardEnabled(duration: .long, isUncommon: true))

        settings.longVowels = false
        XCTAssertFalse(settings.isVowelCardEnabled(duration: .long, isUncommon: true))
    }

    func test_isVowelCardEnabled_disabledWhenVowelsParentOff() {
        settings.vowelsEnabled = false
        XCTAssertFalse(settings.isVowelCardEnabled(duration: .long, isUncommon: false))
        XCTAssertFalse(settings.isVowelCardEnabled(duration: .short, isUncommon: false))
    }

    // MARK: - isToneRuleEnabled

    func test_isToneRuleEnabled_high_respectsHighToggle() {
        settings.highToneRules = true
        XCTAssertTrue(settings.isToneRuleEnabled(initialConsonant: "High"))

        settings.highToneRules = false
        XCTAssertFalse(settings.isToneRuleEnabled(initialConsonant: "High"))
    }

    func test_isToneRuleEnabled_mid_respectsMidToggle() {
        settings.midToneRules = true
        XCTAssertTrue(settings.isToneRuleEnabled(initialConsonant: "Mid"))

        settings.midToneRules = false
        XCTAssertFalse(settings.isToneRuleEnabled(initialConsonant: "Mid"))
    }

    func test_isToneRuleEnabled_low_respectsLowToggle() {
        settings.lowToneRules = true
        XCTAssertTrue(settings.isToneRuleEnabled(initialConsonant: "Low"))

        settings.lowToneRules = false
        XCTAssertFalse(settings.isToneRuleEnabled(initialConsonant: "Low"))
    }

    func test_isToneRuleEnabled_unknownClass_returnsFalse() {
        XCTAssertFalse(settings.isToneRuleEnabled(initialConsonant: "Unknown"))
    }

    func test_isToneRuleEnabled_disabledWhenTonesParentOff() {
        settings.tonesEnabled = false
        XCTAssertFalse(settings.isToneRuleEnabled(initialConsonant: "High"))
        XCTAssertFalse(settings.isToneRuleEnabled(initialConsonant: "Mid"))
        XCTAssertFalse(settings.isToneRuleEnabled(initialConsonant: "Low"))
    }

    // MARK: - isClusterEnabled

    func test_isClusterEnabled_smoothCluster_respectsToggle() {
        let clusters = Cluster.loadAll()
        guard let smoothCluster = clusters.first(where: { $0.type == .smooth }) else {
            XCTFail("No smooth cluster found in data")
            return
        }

        settings.smoothClusters = true
        XCTAssertTrue(settings.isClusterEnabled(smoothCluster))

        settings.smoothClusters = false
        XCTAssertFalse(settings.isClusterEnabled(smoothCluster))
    }

    func test_isClusterEnabled_silentCluster_respectsToggle() {
        let clusters = Cluster.loadAll()
        guard let silentCluster = clusters.first(where: { $0.type == .silent }) else {
            XCTFail("No silent cluster found in data")
            return
        }

        settings.silentClusters = true
        XCTAssertTrue(settings.isClusterEnabled(silentCluster))

        settings.silentClusters = false
        XCTAssertFalse(settings.isClusterEnabled(silentCluster))
    }

    func test_isClusterEnabled_irregularCluster_respectsToggle() {
        let clusters = Cluster.loadAll()
        guard let irregularCluster = clusters.first(where: { $0.type == .irregular }) else {
            XCTFail("No irregular cluster found in data")
            return
        }

        settings.irregularClusters = true
        XCTAssertTrue(settings.isClusterEnabled(irregularCluster))

        settings.irregularClusters = false
        XCTAssertFalse(settings.isClusterEnabled(irregularCluster))
    }

    func test_isClusterEnabled_disabledWhenClustersParentOff() {
        let clusters = Cluster.loadAll()
        let anyCluster = clusters[0]

        settings.clusters = false
        XCTAssertFalse(settings.isClusterEnabled(anyCluster))
    }

    // MARK: - areToneMarksEnabled

    func test_areToneMarksEnabled_trueWhenBothTogglesOn() {
        settings.tonesEnabled = true
        settings.toneMarks = true
        XCTAssertTrue(settings.areToneMarksEnabled)
    }

    func test_areToneMarksEnabled_falseWhenParentOff() {
        settings.tonesEnabled = false
        settings.toneMarks = true
        XCTAssertFalse(settings.areToneMarksEnabled)
    }

    func test_areToneMarksEnabled_falseWhenToneMarksOff() {
        settings.tonesEnabled = true
        settings.toneMarks = false
        XCTAssertFalse(settings.areToneMarksEnabled)
    }

    // MARK: - isPartialTesting

    func test_isPartialTesting_consonant_trueWhenOnlyOneClassEnabled() {
        settings.highConsonants = true
        settings.midConsonants = false
        settings.lowConsonants = false
        XCTAssertTrue(settings.isPartialTesting(for: .consonant))
    }

    func test_isPartialTesting_consonant_falseWhenMultipleClassesEnabled() {
        settings.highConsonants = true
        settings.midConsonants = true
        settings.lowConsonants = false
        XCTAssertFalse(settings.isPartialTesting(for: .consonant))
    }

    func test_isPartialTesting_consonant_falseWhenAllClassesEnabled() {
        settings.highConsonants = true
        settings.midConsonants = true
        settings.lowConsonants = true
        XCTAssertFalse(settings.isPartialTesting(for: .consonant))
    }

    func test_isPartialTesting_vowel_trueWhenOnlyOneDurationEnabled() {
        settings.longVowels = true
        settings.shortVowels = false
        settings.uncommonVowels = false
        XCTAssertTrue(settings.isPartialTesting(for: .vowel))
    }

    func test_isPartialTesting_vowel_falseWhenMultipleDurationsEnabled() {
        settings.longVowels = true
        settings.shortVowels = true
        settings.uncommonVowels = false
        XCTAssertFalse(settings.isPartialTesting(for: .vowel))
    }

    func test_isPartialTesting_toneMark_alwaysFalse() {
        XCTAssertFalse(settings.isPartialTesting(for: .toneMark))
    }

    func test_isPartialTesting_toneRule_trueWhenOnlyOneClassEnabled() {
        settings.highToneRules = true
        settings.midToneRules = false
        settings.lowToneRules = false
        XCTAssertTrue(settings.isPartialTesting(for: .toneRule))
    }

    func test_isPartialTesting_toneRule_falseWhenMultipleClassesEnabled() {
        settings.highToneRules = true
        settings.midToneRules = true
        settings.lowToneRules = false
        XCTAssertFalse(settings.isPartialTesting(for: .toneRule))
    }

    func test_isPartialTesting_cluster_alwaysFalse() {
        XCTAssertFalse(settings.isPartialTesting(for: .cluster))
    }

    // MARK: - isAllSelected / isNoneSelected

    func test_isAllSelected_trueByDefault() {
        XCTAssertTrue(settings.isAllSelected)
    }

    func test_isAllSelected_falseWhenAnyToggleOff() {
        settings.highConsonants = false
        XCTAssertFalse(settings.isAllSelected)
    }

    func test_isNoneSelected_falseByDefault() {
        XCTAssertFalse(settings.isNoneSelected)
    }

    func test_isNoneSelected_trueWhenAllParentsOff() {
        settings.consonantsEnabled = false
        settings.vowelsEnabled = false
        settings.tonesEnabled = false
        settings.clusters = false
        XCTAssertTrue(settings.isNoneSelected)
    }

    func test_isNoneSelected_falseWhenOneParentOn() {
        settings.consonantsEnabled = true
        settings.vowelsEnabled = false
        settings.tonesEnabled = false
        settings.clusters = false
        XCTAssertFalse(settings.isNoneSelected)
    }

    // MARK: - selectAll / deselectAll

    func test_selectAll_enablesEverything() {
        settings.deselectAll()
        XCTAssertTrue(settings.isNoneSelected)

        settings.selectAll()

        XCTAssertTrue(settings.isAllSelected)
        XCTAssertTrue(settings.consonantsEnabled)
        XCTAssertTrue(settings.vowelsEnabled)
        XCTAssertTrue(settings.tonesEnabled)
        XCTAssertTrue(settings.clusters)
        XCTAssertTrue(settings.highConsonants)
        XCTAssertTrue(settings.midConsonants)
        XCTAssertTrue(settings.lowConsonants)
        XCTAssertTrue(settings.uncommonConsonants)
        XCTAssertTrue(settings.longVowels)
        XCTAssertTrue(settings.shortVowels)
        XCTAssertTrue(settings.uncommonVowels)
        XCTAssertTrue(settings.highToneRules)
        XCTAssertTrue(settings.midToneRules)
        XCTAssertTrue(settings.lowToneRules)
        XCTAssertTrue(settings.toneMarks)
        XCTAssertTrue(settings.smoothClusters)
        XCTAssertTrue(settings.silentClusters)
        XCTAssertTrue(settings.irregularClusters)
    }

    func test_deselectAll_disablesEverything() {
        settings.deselectAll()

        XCTAssertTrue(settings.isNoneSelected)
        XCTAssertFalse(settings.consonantsEnabled)
        XCTAssertFalse(settings.vowelsEnabled)
        XCTAssertFalse(settings.tonesEnabled)
        XCTAssertFalse(settings.clusters)
        XCTAssertFalse(settings.highConsonants)
        XCTAssertFalse(settings.midConsonants)
        XCTAssertFalse(settings.lowConsonants)
        XCTAssertFalse(settings.uncommonConsonants)
        XCTAssertFalse(settings.longVowels)
        XCTAssertFalse(settings.shortVowels)
        XCTAssertFalse(settings.uncommonVowels)
        XCTAssertFalse(settings.highToneRules)
        XCTAssertFalse(settings.midToneRules)
        XCTAssertFalse(settings.lowToneRules)
        XCTAssertFalse(settings.toneMarks)
        XCTAssertFalse(settings.smoothClusters)
        XCTAssertFalse(settings.silentClusters)
        XCTAssertFalse(settings.irregularClusters)
    }

    // MARK: - UserDefaults Persistence
    // Note: Verify defaults directly to avoid @Observable + test host conflicts
    // that cause CoreAudio malloc crashes when creating multiple instances.

    func test_persistence_boolSettingRoundTrip() {
        settings.highConsonants = false
        settings.lowConsonants = false
        settings.useIntelligentSelection = true

        // Verify persisted values directly in UserDefaults
        XCTAssertEqual(defaults.object(forKey: "fc_highConsonants") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "fc_lowConsonants") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "fc_useIntelligentSelection") as? Bool, true)
        // Unset keys should be nil (init provides default)
        XCTAssertNil(defaults.object(forKey: "fc_midConsonants"))
    }

    func test_persistence_deselectAll_thenReload() {
        settings.deselectAll()

        XCTAssertEqual(defaults.object(forKey: "fc_consonantsEnabled") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "fc_vowelsEnabled") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "fc_tonesEnabled") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "fc_clusters") as? Bool, false)
    }

    func test_persistence_selectAll_thenReload() {
        settings.deselectAll()
        settings.selectAll()

        XCTAssertEqual(defaults.object(forKey: "fc_consonantsEnabled") as? Bool, true)
        XCTAssertEqual(defaults.object(forKey: "fc_highConsonants") as? Bool, true)
        XCTAssertEqual(defaults.object(forKey: "fc_longVowels") as? Bool, true)
        XCTAssertEqual(defaults.object(forKey: "fc_toneMarks") as? Bool, true)
    }

    func test_persistence_appLanguage_roundTrip() {
        settings.appLanguage = "fr"

        XCTAssertEqual(defaults.string(forKey: "fc_appLanguage"), "fr")
    }

    func test_migration_legacyDeviceSource_becomesDeviceVoice() {
        let suite = "VoiceMigration_\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suite)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        store.set("device", forKey: "fc_audioSource")

        let migrated = FlashcardSettings(defaults: store)
        XCTAssertEqual(migrated.recordedVoice, .device)
        XCTAssertNil(store.string(forKey: "fc_audioSource")) // legacy key cleared
    }

    func test_migration_legacyDeviceSource_appliesOnReload() {
        // iCloud can deliver the legacy key after launch → reload() must migrate too.
        defaults.set("device", forKey: "fc_audioSource")
        settings.reload()
        XCTAssertEqual(settings.recordedVoice, .device)
        XCTAssertNil(defaults.string(forKey: "fc_audioSource"))
    }

    // MARK: - appLanguage and resolvedLocale

    func test_appLanguage_defaultIsSystem() {
        XCTAssertEqual(settings.appLanguage, "system")
    }

    func test_resolvedLocale_system_returnsCurrent() {
        settings.appLanguage = "system"
        XCTAssertEqual(settings.resolvedLocale, .current)
    }

    func test_resolvedLocale_english_returnsEnLocale() {
        settings.appLanguage = "en"
        XCTAssertEqual(settings.resolvedLocale, Locale(identifier: "en"))
    }

    func test_resolvedLocale_french_returnsFrLocale() {
        settings.appLanguage = "fr"
        XCTAssertEqual(settings.resolvedLocale, Locale(identifier: "fr"))
    }

    // MARK: - Filter Counts

    func test_enabledVowelFilterCount_allEnabled_returns3() {
        XCTAssertEqual(settings.enabledVowelFilterCount, 3)
    }

    // MARK: - Supported Languages

    func test_supportedLanguages_containsSystemEnglishFrench() {
        let codes = FlashcardSettings.supportedLanguages.map(\.code)
        XCTAssertEqual(codes, ["system", "en", "fr"])
    }

    // MARK: - Voice overrides

    func test_voiceOverride_persistsAndReloadsInSecondInstance() {
        settings.setVoiceOverride(.kore, for: "consonant-ก")
        let reloaded = FlashcardSettings(defaults: defaults)
        XCTAssertEqual(reloaded.voiceOverride(for: "consonant-ก"), .kore)
    }

    func test_voiceOverride_corruptDataDecodesToEmptyMap() {
        defaults.set(Data("not json".utf8), forKey: "fc_voiceOverrides")
        let reloaded = FlashcardSettings(defaults: defaults)
        XCTAssertTrue(reloaded.voiceOverrides.isEmpty)
    }

    func test_voiceOverride_removeOne() {
        settings.setVoiceOverride(.kore, for: "consonant-ก")
        settings.setVoiceOverride(.matilda, for: "consonant-ข")
        settings.setVoiceOverride(nil, for: "consonant-ก")
        XCTAssertNil(settings.voiceOverride(for: "consonant-ก"))
        XCTAssertEqual(settings.voiceOverride(for: "consonant-ข"), .matilda)
    }

    func test_resetVoiceOverrides_empties() {
        settings.setVoiceOverride(.kore, for: "consonant-ก")
        settings.setVoiceOverride(.matilda, for: "vowel-x")
        settings.resetVoiceOverrides()
        XCTAssertTrue(settings.voiceOverrides.isEmpty)
        XCTAssertTrue(settings.overriddenItemIDs.isEmpty)
    }

    func test_changingDefaultVoice_preservesOverrides() {
        settings.setVoiceOverride(.kore, for: "consonant-ก")
        settings.recordedVoice = .current
        XCTAssertEqual(settings.voiceOverride(for: "consonant-ก"), .kore)
    }

    func test_reload_picksUpExternalOverrideChange() {
        defaults.set(FlashcardSettings.encodeVoiceOverrides(["cluster-กร": .matilda]), forKey: "fc_voiceOverrides")
        settings.reload()
        XCTAssertEqual(settings.voiceOverride(for: "cluster-กร"), .matilda)
    }

    func test_syncedKeys_containsVoiceOverrides() {
        XCTAssertTrue(FlashcardSettings.syncedKeys.contains("fc_voiceOverrides"))
    }

    func test_voiceOverrides_encodeDecodeRoundTrip() {
        let map: [String: RecordedVoice] = ["a": .kore, "b": .matilda, "c": .current]
        let decoded = FlashcardSettings.decodeVoiceOverrides(FlashcardSettings.encodeVoiceOverrides(map))
        XCTAssertEqual(decoded, map)
        XCTAssertTrue(FlashcardSettings.decodeVoiceOverrides(nil).isEmpty)
    }

    // MARK: - AudioPlayer voice resolution

    func test_audioPlayer_initializedWithOverrides_resolvesImmediately() {
        let player = AudioPlayer(recordedVoice: .current, voiceOverrides: ["consonant-ก": .kore])
        XCTAssertEqual(player.resolvedVoice(for: "consonant-ก", previewVoice: nil), .kore)
    }

    func test_audioPlayer_resolutionPrecedence() {
        let player = AudioPlayer(recordedVoice: .matilda, voiceOverrides: ["x": .kore])
        XCTAssertEqual(player.resolvedVoice(for: "x", previewVoice: .current), .current) // preview wins
        XCTAssertEqual(player.resolvedVoice(for: "x", previewVoice: nil), .kore)          // then override
        XCTAssertEqual(player.resolvedVoice(for: "y", previewVoice: nil), .matilda)       // then default
        XCTAssertEqual(player.resolvedVoice(for: nil, previewVoice: nil), .matilda)
    }

    func test_audioPlayer_resolvesDeviceVoice() {
        let player = AudioPlayer(recordedVoice: .device, voiceOverrides: ["x": .kore])
        XCTAssertEqual(player.resolvedVoice(for: "y", previewVoice: nil), .device)  // device as default
        XCTAssertEqual(player.resolvedVoice(for: "x", previewVoice: nil), .kore)    // override still wins
        XCTAssertEqual(player.resolvedVoice(for: nil, previewVoice: .device), .device) // device preview
    }
}

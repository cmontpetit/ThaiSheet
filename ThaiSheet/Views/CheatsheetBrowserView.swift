//
//  CheatsheetBrowserView.swift
//  ThaiSheet
//

import SwiftUI

// Tones goes last: it has no filter chips, so keeping the chip-bearing
// sections adjacent minimizes layout jumps when switching sections.
enum CheatsheetEntryType: String, CaseIterable {
    case consonants
    case vowels
    case clusters
    case tones

    var label: String {
        switch self {
        case .consonants: return String(localized: "Consonants", bundle: .appLanguage)
        case .vowels: return String(localized: "Vowels", bundle: .appLanguage)
        case .clusters: return String(localized: "Clusters", bundle: .appLanguage)
        case .tones: return String(localized: "Tones", bundle: .appLanguage)
        }
    }

    /// Abbreviated label used when result counts are appended: the segmented
    /// picker gives every segment equal width, so full names get truncated
    var shortLabel: String {
        switch self {
        case .consonants: return String(localized: "Cons.", bundle: .appLanguage)
        case .vowels: return String(localized: "Vow.", bundle: .appLanguage)
        case .clusters: return String(localized: "Clus.", bundle: .appLanguage)
        case .tones: return String(localized: "Tones", bundle: .appLanguage)
        }
    }
}

struct CheatsheetBrowserView: View {
    var settings: FlashcardSettings
    var syncedStore: SyncedKeyValueStore? = nil

    // Navigation bindings (dictionaries keyed by FlashcardType)
    @Binding var highlighted: [FlashcardType: String]
    @Binding var flashcardStarting: [FlashcardType: String]
    @Binding var selectedTab: AppTab

    @Environment(\.thaiData) private var thaiData

    @State private var searchText = ""
    @State private var selectedType: CheatsheetEntryType =
        ScreenshotScenario.current?.referenceType ?? .consonants
    @State private var showingSettings = false
    @State private var showingToneLegend = false
    // Session-only by design: the app always opens with readings visible
    @State private var practiceMode = ScreenshotScenario.initialPracticeMode

    private var consonants: [Consonant] { thaiData.consonants }
    private var vowels: [Vowel] { thaiData.vowels }
    private var toneRules: [ToneRule] { thaiData.toneRules }
    private var toneMarks: [ToneMark] { thaiData.toneMarks }
    private var clusters: [Cluster] { thaiData.clusters }

    // Filters
    @State private var selectedConsonantClass: ConsonantClass? = nil
    @State private var selectedClusterType: ClusterType? = nil
    @State private var selectedVowelDuration: VowelCard.VowelDuration? = nil
    @State private var showRareVowels = false

    // Convenience accessors for highlighted values
    private var highlightedConsonant: String? { highlighted[.consonant] }
    private var highlightedVowel: String? { highlighted[.vowel] }
    private var highlightedToneMark: String? { highlighted[.toneMark] }
    private var highlightedToneRule: String? { highlighted[.toneRule] }
    private var highlightedCluster: String? { highlighted[.cluster] }

    /// Start practicing a card: set the starting value and switch to flashcards
    private func startPractice(_ key: String, type: FlashcardType) {
        flashcardStarting[type] = key
        highlighted[type] = nil
        selectedTab = .flashcards
    }

    var filteredConsonants: [Consonant] {
        var result = consonants

        // Apply class filter
        if let classFilter = selectedConsonantClass {
            result = result.filter { $0.consonantClass == classFilter }
        }

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { consonant in
                // Match Thai character
                if consonant.character.contains(searchText) {
                    return true
                }
                // Match initial or final sound (case insensitive)
                if consonant.initialSound.lowercased().contains(query) ||
                   consonant.finalSound.lowercased().contains(query) {
                    return true
                }
                return false
            }
        }

        return result
    }

    // Normalized search query for vowels (prepends ก to combining characters)
    private var normalizedVowelSearch: String? {
        guard !searchText.isEmpty else { return nil }
        return ThaiDisplay.normalizeSearch(searchText)
    }

    var filteredVowels: [Vowel] {
        var result = vowels

        if let duration = selectedVowelDuration {
            result = result.filter { $0.hasForm(for: duration) }
        }

        guard let normalizedSearch = normalizedVowelSearch else {
            // No search: hide rare/archaic rows unless the Rare toggle is on
            return showRareVowels ? result : result.filter { !$0.isUncommon }
        }

        // Don't match vowels if searching for just the placeholder consonant
        if searchText == "ก" { return [] }

        // Searching bypasses the rare toggle so matches are never hidden
        let query = searchText.lowercased()
        return result.filter { vowel in
            vowel.allForms.contains { $0.contains(normalizedSearch) } ||
            vowel.sound.lowercased().contains(query)
        }
    }

    /// Duration selection chips plus the independent "Rare" visibility toggle
    private var vowelFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChipView(
                    label: String(localized: "All", bundle: .appLanguage),
                    isSelected: selectedVowelDuration == nil,
                    action: { selectedVowelDuration = nil }
                )
                ForEach(VowelCard.VowelDuration.allCases, id: \.self) { duration in
                    FilterChipView(
                        label: duration.label,
                        isSelected: selectedVowelDuration == duration,
                        action: { selectedVowelDuration = duration }
                    )
                }
                FilterChipView(
                    label: String(localized: "Rare", bundle: .appLanguage),
                    isSelected: showRareVowels,
                    color: .pink,
                    action: { showRareVowels.toggle() }
                )
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
        .contentColumn()
    }

    /// Matches a data identifier (e.g. "Falling") against the query in both
    /// its raw form and its localized display form
    private func matchesQuery(_ value: String, query: String) -> Bool {
        value.lowercased().contains(query) ||
        String(localized: String.LocalizationValue(value), bundle: .appLanguage).lowercased().contains(query)
    }

    var filteredToneRules: [ToneRule] {
        guard !searchText.isEmpty else { return toneRules }

        let query = searchText.lowercased()
        return toneRules.filter { rule in
            matchesQuery(rule.initialConsonant, query: query) ||
            matchesQuery(rule.vowelDuration, query: query) ||
            matchesQuery(rule.end, query: query) ||
            matchesQuery(rule.tone, query: query)
        }
    }

    var filteredToneMarks: [ToneMark] {
        guard !searchText.isEmpty else { return toneMarks }

        // Don't match tone marks if searching for just the placeholder consonant
        if searchText == "ก" { return [] }

        let query = searchText.lowercased()
        let normalizedSearch = ThaiDisplay.normalizeSearch(searchText)
        return toneMarks.filter { mark in
            mark.classEntries.contains { entry in
                guard let tone = entry.tone else { return false }
                return entry.display.contains(normalizedSearch) ||
                       entry.soundKey.contains(normalizedSearch) ||
                       matchesQuery(tone, query: query)
            }
        }
    }

    var filteredClusters: [Cluster] {
        var result = clusters

        // Apply type filter
        if let typeFilter = selectedClusterType {
            result = result.filter { $0.type == typeFilter }
        }

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { cluster in
                cluster.cluster.contains(searchText) ||
                (cluster.sound?.lowercased().contains(query) ?? false) ||
                cluster.type.displayName.lowercased().contains(query)
            }
        }

        return result
    }

    private func tabLabel(for type: CheatsheetEntryType) -> String {
        guard !searchText.isEmpty else { return type.label }

        let count: Int
        switch type {
        case .consonants:
            count = filteredConsonants.count
        case .vowels:
            count = filteredVowels.count
        case .tones:
            count = filteredToneRules.count + filteredToneMarks.count
        case .clusters:
            count = filteredClusters.count
        }
        return String(localized: "\(type.shortLabel) (\(count))", bundle: .appLanguage)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Type", selection: $selectedType) {
                    ForEach(CheatsheetEntryType.allCases, id: \.self) { type in
                        Text(tabLabel(for: type)).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .contentColumn()

                // Filter chips
                if selectedType == .consonants {
                    FilterChipRow(
                        items: ConsonantClass.allCases,
                        label: { $0.label },
                        color: { $0.color },
                        selection: $selectedConsonantClass
                    )
                }
                if selectedType == .clusters {
                    FilterChipRow(
                        items: ClusterType.allCases,
                        label: { $0.chipLabel },
                        selection: $selectedClusterType
                    )
                }
                if selectedType == .vowels {
                    vowelFilterChips
                }

                switch selectedType {
                case .consonants:
                    if filteredConsonants.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                    VStack(spacing: 0) {
                        ConsonantHeaderView()
                        Divider()
                        ScrollViewReader { proxy in
                            List(filteredConsonants) { consonant in
                                ConsonantRowView(
                                    consonant: consonant,
                                    isHighlighted: highlightedConsonant == consonant.character,
                                    onPractice: {
                                        startPractice(consonant.character, type: .consonant)
                                    }
                                )
                                .listRowInsets(EdgeInsets())
                                .id(consonant.character)
                            }
                            .listStyle(.plain)
                            .scrollsToHighlight(highlightedConsonant, proxy: proxy) { $0 }
                        }
                    }
                    .contentColumn()
                    }
                case .vowels:
                    if filteredVowels.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                    VStack(spacing: 0) {
                        VowelHeaderView(visibleDuration: selectedVowelDuration)
                        Divider()
                        ScrollViewReader { proxy in
                            List(filteredVowels) { vowel in
                                VowelRowView(
                                    vowel: vowel,
                                    highlightedForm: highlightedVowel,
                                    searchQuery: normalizedVowelSearch,
                                    visibleDuration: selectedVowelDuration,
                                    onPractice: { form in
                                        startPractice(form, type: .vowel)
                                    }
                                )
                                .listRowInsets(EdgeInsets())
                                .id(vowel.id)
                            }
                            .listStyle(.plain)
                            .scrollsToHighlight(highlightedVowel, proxy: proxy) { form in
                                vowels.first { $0.allForms.contains(form) }?.id
                            }
                        }
                    }
                    .contentColumn()
                    }
                case .tones:
                    if filteredToneMarks.isEmpty && filteredToneRules.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                // Tone Marks table
                                if !filteredToneMarks.isEmpty {
                                    VStack(spacing: 0) {
                                        ToneMarkHeaderView()
                                        Divider()
                                        ForEach(filteredToneMarks) { mark in
                                            // Match on soundKey (ค่า): that's what flashcards pass
                                            let isMarkHighlighted = mark.classEntries
                                                .contains { $0.soundKey == highlightedToneMark }
                                            ToneMarkRowView(
                                                toneMark: mark,
                                                isHighlighted: isMarkHighlighted
                                            ) { display in
                                                startPractice(display, type: .toneMark)
                                            }
                                            .id("tonemark-\(mark.id)")
                                            Divider()
                                        }
                                    }
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                // Tone Rules table (unmarked syllables only —
                                // marked syllables follow the tone-mark table above)
                                if !filteredToneRules.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Unmarked syllable tone rules")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .padding(.leading, 4)
                                            .accessibilityAddTraits(.isHeader)
                                        VStack(spacing: 0) {
                                            ToneRuleHeaderView()
                                            Divider()
                                            ForEach(filteredToneRules) { rule in
                                                ToneRuleRowView(
                                                    rule: rule,
                                                    isHighlighted: highlightedToneRule == rule.id
                                                ) {
                                                    startPractice(rule.id, type: .toneRule)
                                                }
                                                .id("tonerule-\(rule.id)")
                                                Divider()
                                            }
                                        }
                                        .background(Color(.systemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .contentColumn()
                        }
                        .scrollsToHighlight(highlightedToneMark, proxy: proxy) { display in
                            toneMarks
                                .first { mark in mark.classEntries.contains { $0.soundKey == display } }
                                .map { "tonemark-\($0.id)" }
                        }
                        .scrollsToHighlight(highlightedToneRule, proxy: proxy) { "tonerule-\($0)" }
                    }
                    .background(Color(.secondarySystemBackground))
                    }
                case .clusters:
                    if filteredClusters.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                // Matrix view for smooth clusters
                                if filteredClusters.contains(where: { $0.type == .smooth }) {
                                    ClusterMatrixView(
                                        clusters: filteredClusters,
                                        highlightedClusterId: highlightedCluster
                                    ) { clusterId in
                                        startPractice(clusterId, type: .cluster)
                                    }
                                }
                                // Compact grids for silent and irregular clusters
                                ForEach([ClusterType.silent, .irregular], id: \.self) { type in
                                    if filteredClusters.contains(where: { $0.type == type }) {
                                        ClusterGridSection(
                                            type: type,
                                            clusters: filteredClusters,
                                            highlightedClusterId: highlightedCluster
                                        ) { clusterId in
                                            startPractice(clusterId, type: .cluster)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .contentColumn()
                        }
                        .scrollsToHighlight(highlightedCluster, proxy: proxy) { $0 }
                    }
                    .background(Color(.secondarySystemBackground))
                    }
                }
            }
            .environment(\.practiceMode, practiceMode)
            .searchable(text: $searchText, prompt: "Thai character or sound (e.g. kh)")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            practiceMode.toggleActive()
                        } label: {
                            Image(systemName: practiceMode.isActive ? "eye.slash" : "eye")
                        }
                        .accessibilityLabel(
                            practiceMode.isActive
                                ? String(localized: "Show readings", bundle: .appLanguage)
                                : String(localized: "Hide readings", bundle: .appLanguage)
                        )
                        if selectedType == .tones {
                            Button {
                                showingToneLegend = true
                            } label: {
                                Image(systemName: "info.circle")
                            }
                            .accessibilityLabel(String(localized: "Tone legend", bundle: .appLanguage))
                            .popover(isPresented: $showingToneLegend) {
                                ToneLegendView()
                                    .presentationCompactAdaptation(.popover)
                            }
                        }
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(settings: settings, syncedStore: syncedStore)
            }
        }
        .onChange(of: highlighted) { _, newValue in
            // Switch to the section of whichever item was just highlighted
            if newValue[.consonant] != nil {
                selectedType = .consonants
                selectedConsonantClass = nil
            } else if let form = newValue[.vowel] {
                selectedType = .vowels
                selectedVowelDuration = nil
                if vowels.first(where: { $0.allForms.contains(form) })?.isUncommon == true {
                    showRareVowels = true
                }
            } else if newValue[.toneMark] != nil || newValue[.toneRule] != nil {
                selectedType = .tones
            } else if newValue[.cluster] != nil {
                selectedType = .clusters
                selectedClusterType = nil
            }
        }
    }
}

// MARK: - Scroll to Highlight

private extension View {
    /// Scrolls to the resolved id when `highlighted` is set: once on appear
    /// (after a short delay so the list has laid out) and on every change.
    func scrollsToHighlight<ID: Hashable>(
        _ highlighted: String?,
        proxy: ScrollViewProxy,
        id resolve: @escaping (String) -> ID?
    ) -> some View {
        self
            .task {
                if let value = highlighted, let id = resolve(value) {
                    try? await Task.sleep(for: .milliseconds(100))
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
            .onChange(of: highlighted) { _, newValue in
                if let value = newValue, let id = resolve(value) {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
    }
}

#Preview {
    CheatsheetBrowserView(
        settings: FlashcardSettings(),
        highlighted: .constant([:]),
        flashcardStarting: .constant([:]),
        selectedTab: .constant(.reference)
    )
}

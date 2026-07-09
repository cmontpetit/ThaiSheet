//
//  CheatsheetBrowserView.swift
//  ThaiSheet
//

import SwiftUI

enum CheatsheetEntryType: String, CaseIterable {
    case consonants
    case vowels
    case tones
    case clusters

    var label: String {
        switch self {
        case .consonants: return String(localized: "Consonants")
        case .vowels: return String(localized: "Vowels")
        case .tones: return String(localized: "Tones")
        case .clusters: return String(localized: "Clusters")
        }
    }
}

struct CheatsheetBrowserView: View {
    // Navigation bindings (dictionaries keyed by FlashcardType)
    @Binding var highlighted: [FlashcardType: String]
    @Binding var flashcardStarting: [FlashcardType: String]
    @Binding var selectedTab: AppTab

    @Environment(\.thaiData) private var thaiData

    @State private var searchText = ""
    @State private var selectedType: CheatsheetEntryType = .consonants

    private var consonants: [Consonant] { thaiData.consonants }
    private var vowels: [Vowel] { thaiData.vowels }
    private var toneRules: [ToneRule] { thaiData.toneRules }
    private var toneMarks: [ToneMark] { thaiData.toneMarks }
    private var clusters: [Cluster] { thaiData.clusters }

    // Filters
    @State private var selectedConsonantClass: ConsonantClass? = nil
    @State private var selectedClusterType: ClusterType? = nil

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
        guard let normalizedSearch = normalizedVowelSearch else { return vowels }

        // Don't match vowels if searching for just the placeholder consonant
        if searchText == "ก" { return [] }

        let query = searchText.lowercased()
        return vowels.filter { vowel in
            vowel.allForms.contains { $0.contains(normalizedSearch) } ||
            vowel.sound.lowercased().contains(query)
        }
    }

    var filteredToneRules: [ToneRule] {
        guard !searchText.isEmpty else { return toneRules }

        let query = searchText.lowercased()
        return toneRules.filter { rule in
            rule.initialConsonant.lowercased().contains(query) ||
            rule.vowelDuration.lowercased().contains(query) ||
            rule.end.lowercased().contains(query) ||
            rule.tone.lowercased().contains(query)
        }
    }

    var filteredToneMarks: [ToneMark] {
        guard !searchText.isEmpty else { return toneMarks }

        // Don't match tone marks if searching for just the placeholder consonant
        if searchText == "ก" { return [] }

        let query = searchText.lowercased()
        let normalizedSearch = ThaiDisplay.normalizeSearch(searchText)
        return toneMarks.filter { mark in
            mark.withLowConsonant.contains(normalizedSearch) ||
            mark.withMidHighConsonant.contains(normalizedSearch) ||
            mark.onLowConsonant.lowercased().contains(query) ||
            mark.onMidHighConsonant.lowercased().contains(query)
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
        return "\(type.label) (\(count))"
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

                switch selectedType {
                case .consonants:
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
                case .vowels:
                    VStack(spacing: 0) {
                        VowelHeaderView()
                        Divider()
                        ScrollViewReader { proxy in
                            List(filteredVowels) { vowel in
                                VowelRowView(
                                    vowel: vowel,
                                    highlightedForm: highlightedVowel,
                                    searchQuery: normalizedVowelSearch,
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
                case .tones:
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                // Tone Marks table
                                VStack(spacing: 0) {
                                    ToneMarkHeaderView()
                                    Divider()
                                    ForEach(filteredToneMarks) { mark in
                                        let isMarkHighlighted = highlightedToneMark == mark.withLowConsonant ||
                                                                highlightedToneMark == mark.withMidHighConsonant
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

                                // Tone Rules table
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
                            .padding(.horizontal)
                        }
                        .scrollsToHighlight(highlightedToneMark, proxy: proxy) { display in
                            toneMarks
                                .first { $0.withLowConsonant == display || $0.withMidHighConsonant == display }
                                .map { "tonemark-\($0.id)" }
                        }
                        .scrollsToHighlight(highlightedToneRule, proxy: proxy) { "tonerule-\($0)" }
                    }
                    .background(Color(.secondarySystemBackground))
                case .clusters:
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
                        }
                        .scrollsToHighlight(highlightedCluster, proxy: proxy) { $0 }
                    }
                    .background(Color(.secondarySystemBackground))
                }
            }
            .searchable(text: $searchText, prompt: "Thai character or sound (e.g. kh)")
        }
        .onChange(of: highlighted) { _, newValue in
            // Switch to the section of whichever item was just highlighted
            if newValue[.consonant] != nil {
                selectedType = .consonants
                selectedConsonantClass = nil
            } else if newValue[.vowel] != nil {
                selectedType = .vowels
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
        highlighted: .constant([:]),
        flashcardStarting: .constant([:]),
        selectedTab: .constant(.reference)
    )
}

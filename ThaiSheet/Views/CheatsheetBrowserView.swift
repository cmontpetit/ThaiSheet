//
//  CheatsheetBrowserView.swift
//  ThaiSheet
//

import SwiftUI

enum CheatsheetEntryType: String, CaseIterable {
    case consonants = "Consonants"
    case vowels = "Vowels"
    case tones = "Tones"
    case clusters = "Clusters"
}

struct CheatsheetBrowserView: View {
    // Navigation bindings
    @Binding var highlightedConsonant: String?
    @Binding var highlightedVowel: String?
    @Binding var highlightedToneMark: String?
    @Binding var highlightedToneRule: String?
    @Binding var flashcardStartingConsonant: String?
    @Binding var flashcardStartingVowel: String?
    @Binding var flashcardStartingToneMark: String?
    @Binding var flashcardStartingToneRule: String?
    @Binding var selectedTab: AppTab

    @State private var searchText = ""
    @State private var selectedType: CheatsheetEntryType = .consonants
    @State private var consonants: [Consonant] = []
    @State private var vowels: [Vowel] = []
    @State private var toneRules: [ToneRule] = []
    @State private var toneMarks: [ToneMark] = []
    @State private var clusters: [Cluster] = []

    // Filters
    @State private var selectedConsonantClass: ConsonantClass? = nil
    @State private var selectedClusterType: ClusterType? = nil

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

    // Thai combining characters that need a base consonant (vowels above/below, tone marks)
    private static let thaiCombiningMarks: CharacterSet = {
        var set = CharacterSet()
        // Vowels: ั ิ ี ึ ื ุ ู
        set.insert(charactersIn: "\u{0E31}\u{0E34}\u{0E35}\u{0E36}\u{0E37}\u{0E38}\u{0E39}")
        // Tone marks and other combining: ็ ่ ้ ๊ ๋ ์ ํ ๎
        set.insert(charactersIn: "\u{0E47}\u{0E48}\u{0E49}\u{0E4A}\u{0E4B}\u{0E4C}\u{0E4D}\u{0E4E}")
        return set
    }()

    private func normalizeThaiSearch(_ text: String) -> String {
        guard let firstScalar = text.unicodeScalars.first,
              Self.thaiCombiningMarks.contains(firstScalar) else {
            return text
        }
        // Prepend ก if text starts with a combining character
        return "ก" + text
    }

    // Normalized search query for vowels (prepends ก to combining characters)
    private var normalizedVowelSearch: String? {
        guard !searchText.isEmpty else { return nil }
        return normalizeThaiSearch(searchText)
    }

    var filteredVowels: [Vowel] {
        guard let normalizedSearch = normalizedVowelSearch else { return vowels }

        let query = searchText.lowercased()
        return vowels.filter { vowel in
            // Match any Thai vowel form
            let forms = [vowel.short.closed, vowel.short.open, vowel.long.closed, vowel.long.open]
            for form in forms.compactMap({ $0 }) {
                if form.contains(normalizedSearch) {
                    return true
                }
            }
            // Match sound
            if vowel.sound.lowercased().contains(query) {
                return true
            }
            return false
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

        let query = searchText.lowercased()
        let normalizedSearch = normalizeThaiSearch(searchText)
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
                cluster.type.rawValue.lowercased().contains(query)
            }
        }

        return result
    }

    private func tabLabel(for type: CheatsheetEntryType) -> String {
        guard !searchText.isEmpty else { return type.rawValue }

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
        return "\(type.rawValue) (\(count))"
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

                // Filter chips for consonants
                if selectedType == .consonants {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChipView(
                                label: "All",
                                isSelected: selectedConsonantClass == nil,
                                action: { selectedConsonantClass = nil }
                            )
                            ForEach(ConsonantClass.allCases, id: \.self) { cls in
                                FilterChipView(
                                    label: cls.label,
                                    isSelected: selectedConsonantClass == cls,
                                    color: cls.color,
                                    action: { selectedConsonantClass = cls }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                }

                // Filter chips for clusters
                if selectedType == .clusters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChipView(
                                label: "All",
                                isSelected: selectedClusterType == nil,
                                action: { selectedClusterType = nil }
                            )
                            ForEach(ClusterType.allCases, id: \.self) { type in
                                FilterChipView(
                                    label: type.displayName.replacingOccurrences(of: " Clusters", with: "").replacingOccurrences(of: " ห Combinations", with: ""),
                                    isSelected: selectedClusterType == type,
                                    action: { selectedClusterType = type }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
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
                                        flashcardStartingConsonant = consonant.character
                                        highlightedConsonant = nil
                                        selectedTab = .flashcards
                                    }
                                )
                                .listRowInsets(EdgeInsets())
                                .id(consonant.character)
                            }
                            .listStyle(.plain)
                            .onChange(of: highlightedConsonant) { _, newValue in
                                if let character = newValue {
                                    withAnimation {
                                        proxy.scrollTo(character, anchor: .center)
                                    }
                                }
                            }
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
                                        flashcardStartingVowel = form
                                        highlightedVowel = nil
                                        selectedTab = .flashcards
                                    }
                                )
                                .listRowInsets(EdgeInsets())
                                .id(vowel.id)
                            }
                            .listStyle(.plain)
                            .onChange(of: highlightedVowel) { _, newValue in
                                if let vowelForm = newValue,
                                   let vowel = vowels.first(where: { v in
                                       [v.short.closed, v.short.open, v.long.closed, v.long.open]
                                           .compactMap { $0 }.contains(vowelForm)
                                   }) {
                                    withAnimation {
                                        proxy.scrollTo(vowel.id, anchor: .center)
                                    }
                                }
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
                                            flashcardStartingToneMark = display
                                            highlightedToneMark = nil
                                            selectedTab = .flashcards
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
                                            flashcardStartingToneRule = rule.id
                                            highlightedToneRule = nil
                                            selectedTab = .flashcards
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
                        .onChange(of: highlightedToneMark) { _, newValue in
                            if let display = newValue,
                               let mark = toneMarks.first(where: { $0.withLowConsonant == display || $0.withMidHighConsonant == display }) {
                                withAnimation {
                                    proxy.scrollTo("tonemark-\(mark.id)", anchor: .center)
                                }
                            }
                        }
                        .onChange(of: highlightedToneRule) { _, newValue in
                            if let ruleId = newValue {
                                withAnimation {
                                    proxy.scrollTo("tonerule-\(ruleId)", anchor: .center)
                                }
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                case .clusters:
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(Cluster.grouped(filteredClusters), id: \.type) { group in
                                ClusterSectionView(type: group.type, clusters: group.clusters)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .background(Color(.secondarySystemBackground))
                }
            }
            .searchable(text: $searchText, prompt: "Thai character or sound (e.g. kh)")
        }
        .onAppear {
            if consonants.isEmpty {
                consonants = Consonant.loadAll()
            }
            if vowels.isEmpty {
                vowels = Vowel.loadAll()
            }
            if toneRules.isEmpty {
                toneRules = ToneRule.loadAll()
            }
            if toneMarks.isEmpty {
                toneMarks = ToneMark.loadAll()
            }
            if clusters.isEmpty {
                clusters = Cluster.loadAll()
            }
        }
        .onChange(of: highlightedConsonant) { _, newValue in
            // Switch to consonants tab when a consonant is highlighted
            if newValue != nil {
                selectedType = .consonants
                selectedConsonantClass = nil  // Clear filter to ensure consonant is visible
            }
        }
        .onChange(of: highlightedVowel) { _, newValue in
            // Switch to vowels tab when a vowel is highlighted
            if newValue != nil {
                selectedType = .vowels
            }
        }
        .onChange(of: highlightedToneMark) { _, newValue in
            // Switch to tones tab when a tone mark is highlighted
            if newValue != nil {
                selectedType = .tones
            }
        }
        .onChange(of: highlightedToneRule) { _, newValue in
            // Switch to tones tab when a tone rule is highlighted
            if newValue != nil {
                selectedType = .tones
            }
        }
    }
}

#Preview {
    CheatsheetBrowserView(
        highlightedConsonant: .constant(nil),
        highlightedVowel: .constant(nil),
        highlightedToneMark: .constant(nil),
        highlightedToneRule: .constant(nil),
        flashcardStartingConsonant: .constant(nil),
        flashcardStartingVowel: .constant(nil),
        flashcardStartingToneMark: .constant(nil),
        flashcardStartingToneRule: .constant(nil),
        selectedTab: .constant(.reference)
    )
}

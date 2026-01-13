//
//  CheatsheetBrowserView.swift
//  Aksorn
//

import SwiftUI

enum CheatsheetEntryType: String, CaseIterable {
    case consonants = "Consonants"
    case vowels = "Vowels"
    case tones = "Tones"
    case clusters = "Clusters"
}

struct CheatsheetBrowserView: View {
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

    var filteredVowels: [Vowel] {
        guard !searchText.isEmpty else { return vowels }

        let query = searchText.lowercased()
        return vowels.filter { vowel in
            // Match any Thai vowel form (strip placeholder ก before searching)
            let forms = [vowel.short.closed, vowel.short.open, vowel.long.closed, vowel.long.open]
            for form in forms.compactMap({ $0 }) {
                let vowelOnly = form.replacingOccurrences(of: "ก", with: "")
                if !vowelOnly.isEmpty && vowelOnly.contains(searchText) {
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
        return toneMarks.filter { mark in
            mark.toneMark.contains(searchText) ||
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
                        List(filteredConsonants) { consonant in
                            ConsonantRowView(consonant: consonant)
                                .listRowInsets(EdgeInsets())
                        }
                        .listStyle(.plain)
                    }
                case .vowels:
                    VStack(spacing: 0) {
                        VowelHeaderView()
                        Divider()
                        List(filteredVowels) { vowel in
                            VowelRowView(vowel: vowel)
                                .listRowInsets(EdgeInsets())
                        }
                        .listStyle(.plain)
                    }
                case .tones:
                    ScrollView {
                        VStack(spacing: 16) {
                            // Tone Rules table
                            VStack(spacing: 0) {
                                ToneRuleHeaderView()
                                Divider()
                                ForEach(filteredToneRules) { rule in
                                    ToneRuleRowView(rule: rule)
                                    Divider()
                                }
                            }
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            // Tone Marks table
                            VStack(spacing: 0) {
                                ToneMarkHeaderView()
                                Divider()
                                ForEach(filteredToneMarks) { mark in
                                    ToneMarkRowView(mark: mark)
                                    Divider()
                                }
                            }
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.horizontal)
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
            .navigationTitle("Cheatsheet")
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
    }
}

#Preview {
    CheatsheetBrowserView()
}

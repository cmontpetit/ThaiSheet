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
    @Environment(\.learningModel) private var learningModel

    @State private var searchText = ""
    @State private var selectedType: CheatsheetEntryType =
        ScreenshotScenario.current?.referenceType ?? .consonants
    @State private var showingSettings = false
    @State private var showingInfo = false
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

    /// SRS stage raw value for a card id (lower == less learned).
    private func stageValue(forId id: String) -> Int {
        learningModel.getProgress(forId: id).srsStage.rawValue
    }

    /// Consonants after filtering, reordered per the active sort mode.
    private var orderedConsonants: [Consonant] {
        ReferenceOrdering.ordered(
            filteredConsonants,
            from: consonants,
            mode: settings.referenceSortMode,
            seed: settings.referenceShuffleSeed
        ) { consonant in
            stageValue(forId: FlashcardType.consonant.cardId(for: consonant.id))
        }
    }

    /// Vowels after filtering, reordered per the active sort mode. A vowel row's
    /// least-learned rank is the minimum stage across its forms (weakest form wins).
    private var orderedVowels: [Vowel] {
        ReferenceOrdering.ordered(
            filteredVowels,
            from: vowels,
            mode: settings.referenceSortMode,
            seed: settings.referenceShuffleSeed
        ) { vowel in
            let ids = vowel.allForms.map { FlashcardType.vowel.cardId(for: $0) }
            return ReferenceOrdering.minimumStage(for: ids) { stageValue(forId: $0) }
        }
    }

    /// Reorder menu for the flat-list sections. Uses Buttons (not a Picker) so that
    /// re-selecting Shuffle mints a fresh seed and reshuffles.
    private var sortMenu: some View {
        Menu {
            sortMenuItem(.original, titleKey: "Default order") {
                settings.referenceSortMode = .original
            }
            sortMenuItem(.leastLearned, titleKey: "Least learned") {
                settings.referenceSortMode = .leastLearned
            }
            sortMenuItem(.shuffle, titleKey: "Shuffle") {
                settings.reshuffleReference()
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel(String(localized: "Sort order", bundle: .appLanguage))
    }

    private func sortMenuItem(
        _ mode: ReferenceSortMode,
        titleKey: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                Text(titleKey)
            } icon: {
                if settings.referenceSortMode == mode {
                    Image(systemName: "checkmark")
                }
            }
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
                            List(orderedConsonants) { consonant in
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
                            List(orderedVowels) { vowel in
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
                // Reorder menu — only the flat-list sections (Consonants, Vowels) can
                // be shuffled/sorted; Clusters (matrix) and Tones (tables) keep their
                // structured layouts. Kept as its own ToolbarItem (not folded into the
                // HStack below) so the shared glass capsule re-measures when it appears
                // or disappears on a segment change — an intra-HStack conditional left
                // the capsule sized for the other item count and clipped its ends.
                if selectedType == .consonants || selectedType == .vowels {
                    ToolbarItem(placement: .topBarTrailing) {
                        sortMenu
                    }
                }
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
                        Button {
                            settings.hasSeenReferenceInfo = true
                            showingInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                // One-time discoverability nudge: a small badge
                                // draws the eye to the ⓘ, then never returns once
                                // the popover has been opened.
                                .overlay(alignment: .topTrailing) {
                                    if !settings.hasSeenReferenceInfo {
                                        // Sit the badge on the glyph's corner, not
                                        // above it — the toolbar's glass capsule
                                        // clips anything past the icon's frame.
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 6, height: 6)
                                            .offset(x: 1, y: 1)
                                    }
                                }
                        }
                        .accessibilityLabel(String(localized: "How to use", bundle: .appLanguage))
                        .popover(isPresented: $showingInfo) {
                            ReferenceInfoView(
                                isPracticeActive: practiceMode.isActive,
                                showToneLegend: selectedType == .tones
                            )
                            .presentationCompactAdaptation(.popover)
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

/// Content of the ⓘ "how to use" popover shown from the toolbar in every
/// reference section. It explains the tap/long-press interaction (compact, so
/// it costs no space in the dense tables) and, on the Tones section, folds in
/// the tone-diacritic legend so there is a single info affordance per segment.
/// Wording adapts to practice mode, where a tap reveals the concealed reading.
private struct ReferenceInfoView: View {
    let isPracticeActive: Bool
    let showToneLegend: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                // Only the tap action is practice-aware (a tap reveals the
                // concealed reading); the hold always opens details. Separate
                // Text calls, not a String ternary, so each keeps its
                // LocalizedStringKey and localizes via the environment locale.
                if isPracticeActive {
                    Text("Tap to reveal and hear.")
                } else {
                    Text("Tap to hear.")
                }
            } icon: {
                Image(systemName: "speaker.wave.2")
            }

            Label("Touch and hold for details.", systemImage: "hand.tap")

            if showToneLegend {
                Divider()
                ToneLegendView()
            }
        }
        .font(.footnote)
        .fixedSize(horizontal: false, vertical: true)
        .padding()
        .frame(maxWidth: 300, alignment: .leading)
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

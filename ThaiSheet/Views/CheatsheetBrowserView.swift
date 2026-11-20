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

    /// The bundled catalogs this section needs. A section whose data failed
    /// shows an unavailable state; the others stay browsable.
    var requiredDatasets: [ThaiDataset] {
        switch self {
        case .consonants: return [.consonants]
        case .vowels: return [.vowels]
        case .clusters: return [.clusters]
        case .tones: return [.toneMarks, .toneRules]
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
    @Environment(\.referenceViewport) private var referenceViewport

    @ScaledMetric(relativeTo: .body) private var searchFieldHeight: CGFloat = 44
    @State private var searchText = ScreenshotScenario.initialSearchText
    @State private var isSearchFocused = ScreenshotScenario.current == .vowelsSearching
    @State private var selectedType: CheatsheetEntryType =
        ScreenshotScenario.current?.referenceType ?? .consonants
    @State private var referenceSelection = ScreenshotScenario.initialReferenceSelection
    @State private var showingSettings = false
    @State private var showingInfo = false
    @State private var showingBookChapters = false
    @State private var showingToneFinder = ScreenshotScenario.current == .toneFinder
    /// Bumped on every "Show in the table" from the tone finder, so asking
    /// for the row that is already highlighted still scrolls to it
    @State private var toneFinderScrollRequest = 0
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

    init(
        settings: FlashcardSettings,
        syncedStore: SyncedKeyValueStore? = nil,
        highlighted: Binding<[FlashcardType: String]>,
        flashcardStarting: Binding<[FlashcardType: String]>,
        selectedTab: Binding<AppTab>,
        referenceSelection: ReferenceSelection = ScreenshotScenario.initialReferenceSelection,
        referenceType: CheatsheetEntryType? = nil
    ) {
        self.settings = settings
        self.syncedStore = syncedStore
        _highlighted = highlighted
        _flashcardStarting = flashcardStarting
        _selectedTab = selectedTab
        _referenceSelection = State(initialValue: referenceSelection)
        _selectedType = State(initialValue: referenceType ?? ScreenshotScenario.current?.referenceType ?? .consonants)
    }

    // Convenience accessors for highlighted values
    private var highlightedConsonant: String? { highlighted[.consonant] }
    private var highlightedVowel: String? { highlighted[.vowel] }
    private var highlightedToneMark: String? { highlighted[.toneMark] }
    private var highlightedToneRule: String? { highlighted[.toneRule] }
    private var highlightedCluster: String? { highlighted[.cluster] }

    /// Start practicing a card: set the starting value and switch to flashcards
    private func startPractice(_ key: String, type: FlashcardType) {
        referenceSelection.dismissSheet()
        flashcardStarting[type] = key
        highlighted[type] = nil
        selectedTab = .flashcards
    }

    /// Chapter scope for the lists. Not applied while searching: Reference
    /// search includes all chapters. The tab filters (chips) still apply.
    private var bookScope: ReferenceBookScope {
        guard searchText.isEmpty else { return .inactive }
        return ReferenceBookScope(settings: settings, map: thaiData.bookChapters)
            .revealing(highlighted)
    }

    /// An empty section: a search miss; a chip that filtered out everything
    /// the chapter does cover here; or a section the chapter has not reached.
    @ViewBuilder
    private func emptySectionView(_ type: CheatsheetEntryType) -> some View {
        if !searchText.isEmpty || !bookScope.isActive {
            ContentUnavailableView.search(text: searchText)
        } else if hasChapterContentWithoutChips(type) {
            ContentUnavailableView {
                Label("Nothing taught yet with this filter", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("The chosen chapter covers other items in this section.")
            } actions: {
                Button("Show All") { clearChips(type) }
            }
        } else {
            notTaughtYetView
        }
    }

    /// Whether the chapter covers anything in the section once its chips are
    /// cleared (the Content toggles are settings, not chips, and stay).
    private func hasChapterContentWithoutChips(_ type: CheatsheetEntryType) -> Bool {
        let scope = bookScope
        let content = contentFilter
        switch type {
        case .consonants: return consonants.contains { scope.includes($0) && content.includes($0) }
        case .vowels: return vowels.contains { scope.showsRow($0) && content.includes($0) }
        case .clusters: return clusters.contains { scope.includes($0) }
        case .tones: return false
        }
    }

    private func clearChips(_ type: CheatsheetEntryType) {
        switch type {
        case .consonants: selectedConsonantClass = nil
        case .vowels: selectedVowelDuration = nil
        case .clusters: selectedClusterType = nil
        case .tones: break
        }
    }

    private var notTaughtYetView: some View {
        ContentUnavailableView {
            Label("Not taught yet", systemImage: "text.book.closed")
        } description: {
            Text("The book has not reached this section by the chosen chapter. You can change it in Book Chapters.")
        } actions: {
            Button("Open Book Chapters") {
                showingBookChapters = true
            }
        }
    }

    /// The row a jump asked for. A saved search shows it beside its matches.
    private var jumpTarget: ReferenceJumpTarget {
        ReferenceJumpTarget(highlighted: highlighted)
    }

    /// The Content toggles for the lists. Not applied while searching, like
    /// the chapter scope; a jump target stays visible.
    private var contentFilter: ReferenceContentFilter {
        guard searchText.isEmpty else { return .all }
        return ReferenceContentFilter(settings: settings).revealing(highlighted)
    }

    var filteredConsonants: [Consonant] {
        let scope = bookScope
        let content = contentFilter
        var result = consonants.filter { scope.includes($0) && content.includes($0) }

        // Apply class filter
        if let classFilter = selectedConsonantClass {
            result = result.filter { $0.consonantClass == classFilter }
        }

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = ReferenceJumpTarget.searchResults(result, target: jumpTarget.contains) { consonant in
                // Match Thai character
                if consonant.character.contains(searchText) {
                    return true
                }
                // Match initial or final sound (case insensitive)
                if consonant.initialSound.matchesRomanized(query) ||
                   consonant.finalSound.matchesRomanized(query) {
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

    private func vowelRow(_ vowel: Vowel) -> some View {
        VowelRowView(
            vowel: vowel,
            highlightedForm: highlightedVowel,
            searchQuery: normalizedVowelSearch,
            visibleDuration: selectedVowelDuration,
            hiddenForms: bookScope.hiddenForms(of: vowel)
        )
        .listRowInsets(EdgeInsets())
        .id(vowel.id)
    }

    var filteredVowels: [Vowel] {
        var result = vowels

        if let duration = selectedVowelDuration {
            result = result.filter { $0.hasForm(for: duration) }
        }

        // Drop rows whose forms (of the chosen duration) are all beyond the chapter
        let scope = bookScope
        if scope.isActive {
            result = result.filter { scope.showsRow($0, duration: selectedVowelDuration) }
        }

        guard let normalizedSearch = normalizedVowelSearch else {
            // No search: the Content toggle decides rare/archaic rows
            let content = contentFilter
            return result.filter { content.includes($0) }
        }

        // Don't match vowels if searching for just the placeholder consonant
        if searchText == "ก" { return result.filter(jumpTarget.contains) }

        // Searching bypasses the rare toggle so matches are never hidden
        let query = searchText.lowercased()
        return ReferenceJumpTarget.searchResults(result, target: jumpTarget.contains) { vowel in
            vowel.allForms.contains { $0.contains(normalizedSearch) } ||
            vowel.sound.matchesRomanized(query)
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
            stageValue(forId: FlashcardType.consonantCardId(
                for: consonant.id, includesName: settings.consonantNames))
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
            let ids = thaiData.vowelProgressIDs(for: vowel)
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

    /// Duration selection chips. Rare/archaic rows follow the Content toggle
    /// in the Book Chapters sheet.
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
        let scope = bookScope
        guard !searchText.isEmpty else { return toneRules.filter { scope.includes($0) } }

        let query = searchText.lowercased()
        return ReferenceJumpTarget.searchResults(toneRules, target: jumpTarget.contains) { rule in
            matchesQuery(rule.initialConsonant, query: query) ||
            matchesQuery(rule.vowelDuration, query: query) ||
            matchesQuery(rule.end, query: query) ||
            matchesQuery(rule.tone, query: query)
        }
    }

    var filteredToneMarks: [ToneMark] {
        let scope = bookScope
        guard !searchText.isEmpty else { return toneMarks.filter { scope.includes($0) } }

        // Don't match tone marks if searching for just the placeholder consonant
        if searchText == "ก" { return toneMarks.filter(jumpTarget.contains) }

        let query = searchText.lowercased()
        let normalizedSearch = ThaiDisplay.normalizeSearch(searchText)
        return ReferenceJumpTarget.searchResults(toneMarks, target: jumpTarget.contains) { mark in
            mark.classEntries.contains { entry in
                guard let tone = entry.tone else { return false }
                return entry.display.contains(normalizedSearch) ||
                       entry.soundKey.contains(normalizedSearch) ||
                       matchesQuery(tone, query: query)
            }
        }
    }

    var filteredClusters: [Cluster] {
        let scope = bookScope
        var result = clusters.filter { scope.includes($0) }

        // Apply type filter
        if let typeFilter = selectedClusterType {
            result = result.filter { $0.type == typeFilter }
        }

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = ReferenceJumpTarget.searchResults(result, target: jumpTarget.contains) { cluster in
                cluster.cluster.contains(searchText) ||
                (cluster.sound?.matchesRomanized(query) ?? false) ||
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

    /// Shown in place of one section whose bundled catalog failed to load. The
    /// picker stays above it, so the sections that did load remain browsable.
    private var sectionUnavailableView: some View {
        ContentUnavailableView(
            "Section Unavailable",
            systemImage: "exclamationmark.triangle",
            description: Text("ThaiSheet couldn't load the data for this section. Other sections still work, and reinstalling the app usually fixes this.")
        )
    }

    /// Opens the "Why this tone?" sheet from the top of the Tones section
    private var toneFinderButton: some View {
        Button {
            showingToneFinder = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "questionmark.circle")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Why this tone?")
                        .font(.body.weight(.semibold))
                    Text("Find the tone of a syllable, step by step.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var tables: some View {
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

            if !thaiData.isAvailable(selectedType.requiredDatasets) {
                sectionUnavailableView
            } else {
            switch selectedType {
            case .consonants:
                if filteredConsonants.isEmpty {
                    emptySectionView(.consonants)
                } else {
                VStack(spacing: 0) {
                    ConsonantHeaderView()
                    Divider()
                    ScrollViewReader { proxy in
                        List(orderedConsonants) { consonant in
                            ConsonantRowView(
                                consonant: consonant,
                                isHighlighted: highlightedConsonant == consonant.character
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
                    emptySectionView(.vowels)
                } else {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        List {
                            // Basic vowels first, then the vowel-plus-ending
                            // combinations. Each section pins its own column
                            // headings: Closed/Open apply to basic vowels only
                            let basicVowels = orderedVowels.filter { !$0.isCombination }
                            let combinations = orderedVowels.filter(\.isCombination)
                            if !basicVowels.isEmpty {
                                Section {
                                    ForEach(basicVowels) { vowel in
                                        vowelRow(vowel)
                                    }
                                } header: {
                                    VStack(spacing: 0) {
                                        VowelHeaderView(visibleDuration: selectedVowelDuration)
                                        Divider()
                                    }
                                    .textCase(nil)
                                    .listRowInsets(EdgeInsets())
                                }
                            }
                            if !combinations.isEmpty {
                                Section {
                                    ForEach(combinations) { vowel in
                                        vowelRow(vowel)
                                    }
                                } header: {
                                    VowelCombinationHeaderView(visibleDuration: selectedVowelDuration)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .listSectionSpacing(0)
                        .contentMargins(.top, 0, for: .scrollContent)
                        .scrollsToHighlight(highlightedVowel, proxy: proxy) { form in
                            vowels.first { $0.allForms.contains(form) }?.id
                        }
                    }
                }
                .contentColumn()
                }
            case .tones:
                // The Tone Finder works on any syllable, so it stays available
                // when the chosen chapter has no tone tables yet.
                if filteredToneMarks.isEmpty && filteredToneRules.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // Not a search result, so it steps aside while searching
                            if searchText.isEmpty {
                                toneFinderButton
                            }

                            if filteredToneMarks.isEmpty && filteredToneRules.isEmpty {
                                notTaughtYetView
                            }

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
                                        )
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
                                            )
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
                    .scrollsToHighlight(highlightedToneMark, proxy: proxy, repeatRequest: toneFinderScrollRequest) { display in
                        toneMarks
                            .first { mark in mark.classEntries.contains { $0.soundKey == display } }
                            .map { "tonemark-\($0.id)" }
                    }
                    .scrollsToHighlight(highlightedToneRule, proxy: proxy, repeatRequest: toneFinderScrollRequest) { "tonerule-\($0)" }
                }
                .background(Color(.secondarySystemBackground))
                }
            case .clusters:
                if filteredClusters.isEmpty {
                    emptySectionView(.clusters)
                } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // Matrix view for smooth clusters
                            if filteredClusters.contains(where: { $0.type == .smooth }) {
                                ClusterMatrixView(
                                    clusters: filteredClusters,
                                    highlightedClusterId: highlightedCluster
                                )
                            }
                            // Compact grids for silent and irregular clusters
                            ForEach([ClusterType.silent, .irregular], id: \.self) { type in
                                if filteredClusters.contains(where: { $0.type == type }) {
                                    ClusterGridSection(
                                        type: type,
                                        clusters: filteredClusters,
                                        highlightedClusterId: highlightedCluster
                                    )
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
        }
    }

    var body: some View {
        // Read outside the Binding getter so observation invalidates the
        // presenter when only the container presentation changes.
        let showsDetailSheet = canPresentDetailSheet && referenceSelection.isSheetPresented
        NavigationStack {
            VStack(spacing: 0) {
                ReferenceSearchField(text: $searchText, isFocused: $isSearchFocused)
                    .frame(height: searchFieldHeight + 16)
                    .padding(.horizontal, 8)

                ReferenceBrowserLayout(selection: referenceSelection, isSearching: isSearchFocused) {
                    tables
                } detail: {
                    ReferenceDetailPane(selection: referenceSelection) { item in
                        ReferenceSelectedDetail(item: item, onPractice: startPractice)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .environment(\.practiceMode, practiceMode)
            .environment(\.referenceSelection, referenceSelection)
            .toolbar {
                // Reorder menu — only the flat-list sections (Consonants, Vowels) can
                // be shuffled/sorted; Clusters (matrix) and Tones (tables) keep their
                // structured layouts. Separate toolbar items also let the system
                // arrange these controls in the Duo's vertical toolbar.
                if selectedType == .consonants || selectedType == .vowels {
                    ToolbarItem(placement: .topBarTrailing) {
                        sortMenu
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Always shown: the sheet also holds the Content toggles,
                    // even when the chapter mapping failed to load.
                    BookChaptersButton(
                        isActive: BookScope(settings: settings, map: thaiData.bookChapters).isActive
                    ) {
                        showingBookChapters = true
                    }
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
                            showToneLegend: selectedType == .tones,
                            showsInlineDetails: referenceSelection.isExpanded
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
            .sheet(isPresented: $showingSettings) {
                SettingsView(settings: settings, syncedStore: syncedStore)
            }
            .sheet(isPresented: $showingBookChapters) {
                BookChaptersView(settings: settings)
            }
            .sheet(isPresented: $showingToneFinder) {
                ToneFinderView { type, key in
                    // This is an explicit request for the table. Cancel any old
                    // selection, including a sheet handoff queued during rotation.
                    referenceSelection.clear()
                    // Replace, not add: a highlight left by "view in
                    // Reference" from a flashcard would otherwise win in the
                    // observer below and switch to its own section.
                    highlighted = [type: key]
                    toneFinderScrollRequest += 1
                }
            }
            .sheet(isPresented: Binding(
                get: { showsDetailSheet },
                set: { if !$0 && canPresentDetailSheet { referenceSelection.dismissSheet() } }
            )) {
                if let item = referenceSelection.item {
                    ReferenceSelectedDetail(item: item, onPractice: startPractice)
                        .environment(\.referenceDetailPlacement, .sheet)
                }
            }
        }
        .onAppear {
            referenceSelection.setReferenceActive(selectedTab == .reference, viewportSize: referenceViewport?.size)
        }
        .onDisappear {
            isSearchFocused = false
            referenceSelection.setReferenceActive(false, viewportSize: referenceViewport?.size)
        }
        .onChange(of: selectedTab) { _, tab in
            if tab != .reference { isSearchFocused = false }
            referenceSelection.setReferenceActive(tab == .reference, viewportSize: referenceViewport?.size)
        }
        .onChange(of: isSearchFocused) { _, searching in
            // Search takes priority over any automatic compact-sheet handoff.
            if searching { referenceSelection.dismissSheet() }
        }
        .onChange(of: referenceSelection.explicitSheetRequestID) { _, request in
            // A long press / Show details action is an explicit request: finish
            // search first, then let the compact detail sheet open normally.
            if request != nil { isSearchFocused = false }
        }
        .onChange(of: isSelectionVisible) { _, visible in
            if !visible { referenceSelection.clear() }
        }
        .onChange(of: highlighted) { _, newValue in
            // Switch to the section of whichever item was just highlighted
            if newValue[.consonant] != nil {
                selectedType = .consonants
                selectedConsonantClass = nil
            } else if newValue[.vowel] != nil {
                selectedType = .vowels
                selectedVowelDuration = nil
            } else if newValue[.toneMark] != nil || newValue[.toneRule] != nil {
                selectedType = .tones
            } else if newValue[.cluster] != nil {
                selectedType = .clusters
                selectedClusterType = nil
            }
        }
    }

    /// Defer automatic handoff while another Reference presentation or tab is active.
    private var canPresentDetailSheet: Bool {
        selectedTab == .reference && !showingSettings && !showingInfo && !showingBookChapters && !showingToneFinder && !isSearchFocused
    }

    /// Filtering or changing sections must not leave unrelated details visible.
    private var isSelectionVisible: Bool {
        guard let item = referenceSelection.item else { return true }
        guard thaiData.isAvailable(selectedType.requiredDatasets) else { return false }
        switch item {
        case .consonant(let id):
            return selectedType == .consonants && filteredConsonants.contains { $0.id == id }
        case .vowel(let id, let variant, _):
            return selectedType == .vowels && filteredVowels.contains { $0.id == id }
                && (selectedVowelDuration == nil || selectedVowelDuration == variant.duration)
                && !(vowels.first { $0.id == id }.map { bookScope.hiddenForms(of: $0).contains(variant) } ?? false)
        case .toneMark(let id, _):
            return selectedType == .tones && filteredToneMarks.contains { $0.id == id }
        case .toneRule(let id):
            return selectedType == .tones && filteredToneRules.contains { $0.id == id }
        case .cluster(let id):
            return selectedType == .clusters && filteredClusters.contains { $0.id == id }
        }
    }
}

// MARK: - Scroll to Highlight

private extension View {
    /// Scrolls to the resolved id when `highlighted` is set: once on appear
    /// (after a short delay so the list has laid out) and on every change.
    /// A change of `repeatRequest` scrolls again without a new highlight,
    /// for a caller that can ask for the same row twice.
    func scrollsToHighlight<ID: Hashable>(
        _ highlighted: String?,
        proxy: ScrollViewProxy,
        repeatRequest: Int = 0,
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
            .onChange(of: repeatRequest) { _, _ in
                if let value = highlighted, let id = resolve(value) {
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
    let showsInlineDetails: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                // Only the tap action is practice-aware (a tap reveals the
                // concealed reading); the hold always opens details. Separate
                // Text calls, not a String ternary, so each keeps its
                // LocalizedStringKey and localizes via the environment locale.
                if showsInlineDetails {
                    if isPracticeActive {
                        Text("Tap to reveal, hear, and show details.")
                    } else {
                        Text("Tap to hear and show details.")
                    }
                } else if isPracticeActive {
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

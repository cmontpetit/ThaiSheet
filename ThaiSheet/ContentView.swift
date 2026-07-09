//
//  ContentView.swift
//  ThaiSheet
//
//  Created by Claude Montpetit on 2026-01-11.
//

import SwiftUI

enum AppTab: Int {
    case flashcards = 0
    case reference = 1
}

enum FlashcardType: CaseIterable {
    case consonant
    case vowel
    case toneMark
    case toneRule
    case cluster

    var label: String {
        switch self {
        case .consonant: String(localized: "Consonant", bundle: .appLanguage)
        case .vowel: String(localized: "Vowel", bundle: .appLanguage)
        case .toneMark: String(localized: "Tone Mark", bundle: .appLanguage)
        case .toneRule: String(localized: "Tone Rule", bundle: .appLanguage)
        case .cluster: String(localized: "Cluster", bundle: .appLanguage)
        }
    }

    var pluralLabel: String {
        switch self {
        case .consonant: String(localized: "Consonants", bundle: .appLanguage)
        case .vowel: String(localized: "Vowels", bundle: .appLanguage)
        case .toneMark: String(localized: "Tone Marks", bundle: .appLanguage)
        case .toneRule: String(localized: "Tone Rules", bundle: .appLanguage)
        case .cluster: String(localized: "Clusters", bundle: .appLanguage)
        }
    }
}

struct ContentView: View {
    var settings: FlashcardSettings
    var syncedStore: SyncedKeyValueStore?
    @Environment(\.thaiData) private var thaiData
    @State private var learningModel: LearningModel
    @State private var manager: FlashcardManager?
    @State private var selectedTab: AppTab = .reference
    @State private var highlighted: [FlashcardType: String] = [:]
    @State private var flashcardStarting: [FlashcardType: String] = [:]

    init(settings: FlashcardSettings, syncedStore: SyncedKeyValueStore? = nil) {
        self.settings = settings
        self.syncedStore = syncedStore
        let store: KeyValueStore = syncedStore ?? UserDefaults.standard
        _learningModel = State(initialValue: LearningModel(store: store))
    }

    /// Creates a Binding<String?> into a dictionary for a given key
    private func binding(
        for type: FlashcardType,
        in dict: Binding<[FlashcardType: String]>
    ) -> Binding<String?> {
        Binding(
            get: { dict.wrappedValue[type] },
            set: { dict.wrappedValue[type] = $0 }
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CheatsheetBrowserView(
                settings: settings,
                syncedStore: syncedStore,
                highlighted: $highlighted,
                flashcardStarting: $flashcardStarting,
                selectedTab: $selectedTab
            )
            .environment(\.learningModel, learningModel)
            .tabItem {
                Label("Reference", systemImage: "book")
            }
            .tag(AppTab.reference)

            if let manager = manager {
                FlashcardsView(
                    manager: manager,
                    syncedStore: syncedStore,
                    highlighted: $highlighted,
                    flashcardStarting: $flashcardStarting,
                    selectedTab: $selectedTab
                )
                .tabItem {
                    Label("Flashcards", systemImage: "rectangle.on.rectangle")
                }
                .tag(AppTab.flashcards)
            } else {
                ContentUnavailableView(
                    "Loading...",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Loading flashcards")
                )
                .tabItem {
                    Label("Flashcards", systemImage: "rectangle.on.rectangle")
                }
                .tag(AppTab.flashcards)
            }
        }
        .onAppear {
            if manager == nil {
                manager = FlashcardManager(settings: settings, learningModel: learningModel, data: thaiData)
            }
        }
        .onChange(of: selectedTab) { oldTab, _ in
            if oldTab == .reference {
                highlighted.removeAll()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncedStoreDidChange)) { _ in
            settings.reload()
            learningModel.reload()
        }
    }
}

struct FlashcardsView: View {
    var manager: FlashcardManager
    var syncedStore: SyncedKeyValueStore?
    @Binding var highlighted: [FlashcardType: String]
    @Binding var flashcardStarting: [FlashcardType: String]
    @Binding var selectedTab: AppTab

    @State private var showingSettings = false
    @State private var showingStats = false
    @State private var showingFilter = false
    @State private var filterRefreshID = UUID()

    private var typeLabel: String {
        manager.currentCard?.type.label ?? String(localized: "Flashcard", bundle: .appLanguage)
    }

    @ViewBuilder
    private func stageIndicator(for card: FlashcardItem) -> some View {
        let stage = manager.learningModel.srsStage(for: card)
        let isCapped = manager.settings.isPartialTesting(for: card.type)
        StageIndicatorView(stage: stage, isCapped: isCapped)
    }

    /// Helper to set highlight and switch to Reference tab
    private func viewInReference(_ value: String, type: FlashcardType) {
        highlighted[type] = value
        selectedTab = .reference
    }

    /// Flashcard content view for the current card - extracted to reduce body complexity
    @ViewBuilder
    private func flashcardContent(for card: FlashcardItem) -> some View {
        switch card {
        case .consonant(let consonant):
            ConsonantFlashcardView(
                consonant: consonant,
                allConsonants: manager.data.consonants,
                onViewInReference: { viewInReference($0, type: .consonant) },
                onComplete: { correct in
                    let fullTesting = !manager.settings.isPartialTesting(for: .consonant)
                    manager.learningModel.recordResult(for: card, correct: correct, fullTesting: fullTesting)
                },
                onNext: { manager.nextCard() },
                onPrevious: { manager.previousCard() }
            )
        case .vowel(let vowelCard):
            VowelFlashcardView(
                card: vowelCard,
                allVowels: manager.data.vowels,
                onViewInReference: { viewInReference($0, type: .vowel) },
                onComplete: { correct in
                    let fullTesting = !manager.settings.isPartialTesting(for: .vowel)
                    manager.learningModel.recordResult(for: card, correct: correct, fullTesting: fullTesting)
                },
                onNext: { manager.nextCard() },
                onPrevious: { manager.previousCard() }
            )
        case .toneMark(let toneMarkCard):
            ToneMarkFlashcardView(
                card: toneMarkCard,
                onViewInReference: { viewInReference($0, type: .toneMark) },
                onComplete: { correct in
                    let fullTesting = !manager.settings.isPartialTesting(for: .toneMark)
                    manager.learningModel.recordResult(for: card, correct: correct, fullTesting: fullTesting)
                },
                onNext: { manager.nextCard() },
                onPrevious: { manager.previousCard() }
            )
        case .toneRule(let toneRuleCard):
            ToneRuleFlashcardView(
                card: toneRuleCard,
                onViewInReference: { viewInReference($0, type: .toneRule) },
                onComplete: { correct in
                    let fullTesting = !manager.settings.isPartialTesting(for: .toneRule)
                    manager.learningModel.recordResult(for: card, correct: correct, fullTesting: fullTesting)
                },
                onNext: { manager.nextCard() },
                onPrevious: { manager.previousCard() }
            )
        case .cluster(let cluster):
            ClusterFlashcardView(
                cluster: cluster,
                allClusters: manager.data.clusters,
                onViewInReference: { viewInReference($0, type: .cluster) },
                onComplete: { correct in
                    let fullTesting = !manager.settings.isPartialTesting(for: .cluster)
                    manager.learningModel.recordResult(for: card, correct: correct, fullTesting: fullTesting)
                },
                onNext: { manager.nextCard() },
                onPrevious: { manager.previousCard() }
            )
        }
    }

    /// Position indicator for sequential mode (e.g., "12 / 44")
    @ViewBuilder
    private var positionIndicator: some View {
        if !manager.settings.useIntelligentSelection {
            let current = manager.currentIndex + 1
            let total = manager.filteredCards.count
            Text("\(current) / \(total)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// Loading state view
    private var loadingView: some View {
        ContentUnavailableView(
            "Loading...",
            systemImage: "rectangle.on.rectangle",
            description: Text("Loading flashcards")
        )
    }

    /// Empty state view when no cards match filters
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Cards", systemImage: "rectangle.on.rectangle")
        } description: {
            Text("Enable some options in Filters")
        } actions: {
            Button("Open Filters") {
                showingFilter = true
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showingFilter = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    }
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    /// Main toolbar buttons
    private var mainToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
                Button {
                    showingStats = true
                } label: {
                    Image(systemName: "chart.bar")
                }
                Button {
                    showingFilter = true
                } label: {
                    Image(systemName: manager.settings.isAllSelected
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill")
                }
                .id(filterRefreshID)
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }

    /// Card header with type label, position, and stage indicator
    @ViewBuilder
    private func cardHeader(for card: FlashcardItem) -> some View {
        HStack {
            Text(typeLabel)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Spacer()
            positionIndicator
            Spacer()
            stageIndicator(for: card)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    /// Main card view when a card is available
    @ViewBuilder
    private func cardView(for card: FlashcardItem) -> some View {
        VStack(spacing: 0) {
            cardHeader(for: card)
            flashcardContent(for: card)
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { mainToolbar }
    }

    /// Main navigation content
    @ViewBuilder
    private var mainContent: some View {
        if !manager.isLoaded {
            loadingView
        } else if let card = manager.currentCard {
            cardView(for: card)
        } else {
            emptyStateView
        }
    }

    var body: some View {
        NavigationStack {
            mainContent
        }
        .modifier(FlashcardsSheetModifier(
            showingFilter: $showingFilter,
            showingSettings: $showingSettings,
            showingStats: $showingStats,
            filterRefreshID: $filterRefreshID,
            manager: manager,
            syncedStore: syncedStore
        ))
        .modifier(FlashcardsNavigationModifier(
            manager: manager,
            flashcardStarting: $flashcardStarting
        ))
    }
}

// MARK: - View Modifiers for FlashcardsView

/// Modifier for sheet presentations
struct FlashcardsSheetModifier: ViewModifier {
    @Binding var showingFilter: Bool
    @Binding var showingSettings: Bool
    @Binding var showingStats: Bool
    @Binding var filterRefreshID: UUID
    var manager: FlashcardManager
    var syncedStore: SyncedKeyValueStore?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingFilter) {
                FlashcardFilterView(settings: manager.settings)
            }
            .onChange(of: showingFilter) { _, isShowing in
                if !isShowing {
                    filterRefreshID = UUID()
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(settings: manager.settings, syncedStore: syncedStore)
            }
            .sheet(isPresented: $showingStats) {
                SRSStatsView(
                    learningModel: manager.learningModel,
                    filteredCards: manager.filteredCards,
                    allCards: manager.allCards,
                    hasActiveFilters: manager.hasActiveFilters
                )
            }
    }
}

/// Modifier for parent category setting changes
struct ParentSettingsModifier: ViewModifier {
    var manager: FlashcardManager

    func body(content: Content) -> some View {
        content
            .onChange(of: manager.settings.consonantsEnabled) { _, _ in manager.resetToStart() }
            .onChange(of: manager.settings.vowelsEnabled) { _, _ in manager.resetToStart() }
            .onChange(of: manager.settings.tonesEnabled) { _, _ in manager.resetToStart() }
            .onChange(of: manager.settings.clusters) { _, _ in manager.resetToStart() }
    }
}

/// Modifier for consonant and vowel filter changes
struct ConsonantVowelSettingsModifier: ViewModifier {
    var manager: FlashcardManager

    func body(content: Content) -> some View {
        content
            .onChange(of: manager.settings.highConsonants) { _, _ in manager.resetToStart() }
            .onChange(of: manager.settings.midConsonants) { _, _ in manager.resetToStart() }
            .onChange(of: manager.settings.lowConsonants) { _, _ in manager.resetToStart() }
            .onChange(of: manager.settings.uncommonConsonants) { _, _ in manager.resetToStart() }
            .onChange(of: manager.settings.longVowels) { _, _ in manager.resetToStart() }
            .onChange(of: manager.settings.shortVowels) { _, _ in manager.resetToStart() }
    }
}

/// Modifier for tone and cluster filter changes
struct ToneClusterSettingsModifier: ViewModifier {
    var manager: FlashcardManager

    func body(content: Content) -> some View {
        content
            .onChange(of: manager.settings.highToneRules) { _, _ in manager.resetToStart() }
            .onChange(of: manager.settings.midToneRules) { _, _ in manager.resetToStart() }
            .onChange(of: manager.settings.lowToneRules) { _, _ in manager.resetToStart() }
            .onChange(of: manager.settings.toneMarks) { _, _ in manager.resetToStart() }
            .onChange(of: manager.settings.smoothClusters) { _, _ in manager.resetToStart() }
            .onChange(of: manager.settings.silentClusters) { _, _ in manager.resetToStart() }
            .onChange(of: manager.settings.irregularClusters) { _, _ in manager.resetToStart() }
    }
}

/// Combined modifier for all settings change observers
struct FlashcardsSettingsModifier: ViewModifier {
    var manager: FlashcardManager

    func body(content: Content) -> some View {
        content
            .modifier(ParentSettingsModifier(manager: manager))
            .modifier(ConsonantVowelSettingsModifier(manager: manager))
            .modifier(ToneClusterSettingsModifier(manager: manager))
    }
}

/// Modifier for navigation jump handling
struct FlashcardsNavigationModifier: ViewModifier {
    var manager: FlashcardManager
    @Binding var flashcardStarting: [FlashcardType: String]

    private typealias JumpFunc = (String) -> Void

    private var jumpFunctions: [FlashcardType: JumpFunc] {
        [
            .consonant: manager.jumpToConsonant,
            .vowel: manager.jumpToVowel,
            .toneMark: manager.jumpToToneMark,
            .toneRule: manager.jumpToToneRule,
            .cluster: manager.jumpToCluster,
        ]
    }

    func body(content: Content) -> some View {
        content
            .modifier(FlashcardsSettingsModifier(manager: manager))
            .onChange(of: flashcardStarting) { _, newValue in
                for (type, key) in newValue {
                    jumpFunctions[type]?(key)
                }
                flashcardStarting.removeAll()
            }
    }
}

#Preview {
    ContentView(settings: FlashcardSettings())
}

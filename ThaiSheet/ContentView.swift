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
    @State private var selectedTab: AppTab = ScreenshotScenario.current?.initialTab ?? .reference
    @State private var highlighted: [FlashcardType: String] = [:]
    @State private var practiceTarget: ReferenceItem?

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
                practiceTarget: $practiceTarget,
                selectedTab: $selectedTab
            )
            .tabItem {
                Label("Reference", systemImage: "book")
            }
            .tag(AppTab.reference)

            if let manager = manager {
                FlashcardsView(
                    manager: manager,
                    syncedStore: syncedStore,
                    highlighted: $highlighted,
                    practiceTarget: $practiceTarget,
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
        .referenceViewportScope()
        .modifier(FlashcardDeckSyncModifier(settings: settings, manager: manager))
        // Both tabs: detail sheets opened from a flashcard read stages too.
        .environment(\.learningModel, learningModel)
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
            if let manager {
                manager.reloadFromSyncedStore()
            } else {
                settings.reload()
                learningModel.reload()
            }
        }
    }
}

struct FlashcardsView: View {
    var manager: FlashcardManager
    var syncedStore: SyncedKeyValueStore?
    @Binding var highlighted: [FlashcardType: String]
    @Binding var practiceTarget: ReferenceItem?
    @Binding var selectedTab: AppTab

    @State private var showingSettings = false
    @State private var showingStats = ScreenshotScenario.current == .progress
    @State private var showingFilter = false
    @State private var showingStudyContent = false
    @State private var filterRefreshID = UUID()
    /// Set when the last correct answer did not move the card's stage
    @State private var reviewNotice: ReviewNotice?

    /// nil when the chapter mapping failed to load: the scope is Off (the sheet still holds the uncommon-content toggle).
    private var bookChapters: BookChapterMap? { manager.data.bookChapters }

    private var bookScope: BookScope { BookScope(settings: manager.settings, map: bookChapters) }

    private var typeLabel: String {
        manager.currentCard?.type.label ?? String(localized: "Flashcard", bundle: .appLanguage)
    }

    @ViewBuilder
    private func stageIndicator(for card: FlashcardItem) -> some View {
        let stage = manager.learningModel.srsStage(for: card)
        let isCapped = manager.isPartialTesting(card)
        StageIndicatorView(stage: stage, isCapped: isCapped)
    }

    /// Helper to set highlight and switch to Reference tab
    private func viewInReference(_ value: String, type: FlashcardType) {
        highlighted[type] = value
        selectedTab = .reference
    }

    /// Record a quiz answer and give haptic feedback
    private func recordAnswer(for card: FlashcardItem, type: FlashcardType, correct: Bool) {
        let fullTesting = !manager.isPartialTesting(card)
        let learningModel = manager.learningModel
        let outcome = learningModel.recordResult(for: card, correct: correct, fullTesting: fullTesting)
        reviewNotice = outcome == .counted ? nil : ReviewNotice(
            cardID: card.id,
            outcome: outcome,
            progress: learningModel.getProgress(for: card)
        )
        UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
    }

    private func showNext() {
        manager.nextCard()
    }

    private func showPrevious() {
        manager.previousCard()
    }

    /// The current card's notice, if its last correct answer did not move its
    /// stage and its progress has not changed since (Reset All Progress, sync)
    private func reviewNotice(for card: FlashcardItem) -> ReviewNotice? {
        guard let notice = reviewNotice,
              notice.applies(to: card.id, progress: manager.learningModel.getProgress(for: card))
        else { return nil }
        return notice
    }

    /// Flashcard content view for the current card - extracted to reduce body complexity
    @ViewBuilder
    private func flashcardContent(for card: FlashcardItem) -> some View {
        switch card {
        case .consonant(let consonant, let includesName):
            ConsonantFlashcardView(
                consonant: consonant,
                includesName: includesName,
                allConsonants: manager.data.consonants,
                onViewInReference: { viewInReference($0, type: .consonant) },
                onComplete: { recordAnswer(for: card, type: .consonant, correct: $0) },
                onNext: showNext,
                onPrevious: showPrevious
            )
        case .vowel(let vowelCard):
            VowelFlashcardView(
                card: vowelCard,
                allVowels: manager.data.vowels,
                onViewInReference: { viewInReference($0, type: .vowel) },
                onComplete: { recordAnswer(for: card, type: .vowel, correct: $0) },
                onNext: showNext,
                onPrevious: showPrevious
            )
        case .toneMark(let toneMarkCard):
            ToneMarkFlashcardView(
                card: toneMarkCard,
                onViewInReference: { viewInReference($0, type: .toneMark) },
                onComplete: { recordAnswer(for: card, type: .toneMark, correct: $0) },
                onNext: showNext,
                onPrevious: showPrevious
            )
        case .toneRule(let toneRuleCard):
            ToneRuleFlashcardView(
                card: toneRuleCard,
                onViewInReference: { viewInReference($0, type: .toneRule) },
                onComplete: { recordAnswer(for: card, type: .toneRule, correct: $0) },
                onNext: showNext,
                onPrevious: showPrevious
            )
        case .cluster(let cluster):
            ClusterFlashcardView(
                cluster: cluster,
                allClusters: manager.data.clusters,
                onViewInReference: { viewInReference($0, type: .cluster) },
                onComplete: { recordAnswer(for: card, type: .cluster, correct: $0) },
                onNext: showNext,
                onPrevious: showPrevious
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

    /// Shown when bundled learning data failed to load. Loading is synchronous,
    /// so this is a terminal packaging/decoding failure rather than a wait —
    /// a spinner here would never resolve.
    private var dataUnavailableView: some View {
        ContentUnavailableView(
            "Learning Data Unavailable",
            systemImage: "exclamationmark.triangle",
            description: Text("ThaiSheet couldn't load its learning data. Reinstalling the app usually fixes this.")
        )
    }

    /// Empty state view when no cards match filters
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Cards", systemImage: "rectangle.on.rectangle")
        } description: {
            if bookScope.isActive {
                Text("Enable some options in Filters, or choose a later chapter in Study Content")
            } else {
                Text("Enable some options in Filters")
            }
        } actions: {
            Button("Open Filters") {
                showingFilter = true
            }
            .buttonStyle(.borderedProminent)
            // The chapter scope alone can empty the deck.
            if bookScope.isActive {
                Button("Open Study Content") {
                    showingStudyContent = true
                }
            }
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    StudyContentButton(settings: manager.settings, map: bookChapters) {
                        showingStudyContent = true
                    }
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
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showingStats = true
            } label: {
                Image(systemName: "chart.bar")
            }
            StudyContentButton(settings: manager.settings, map: bookChapters) {
                showingStudyContent = true
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

    /// Card header with type label, position, and stage indicator
    @ViewBuilder
    private func cardHeader(for card: FlashcardItem) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
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
            if let notice = reviewNotice(for: card) {
                ReviewOutcomeHint(outcome: notice.outcome)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .contentColumn(maxWidth: 1100)
    }

    /// Main card view when a card is available
    @ViewBuilder
    private func cardView(for card: FlashcardItem) -> some View {
        VStack(spacing: 0) {
            cardHeader(for: card)
            flashcardContent(for: card)
                .id(manager.attempt)
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { mainToolbar }
    }

    /// Main navigation content
    @ViewBuilder
    private var mainContent: some View {
        switch manager.data.loadState {
        case .failed:
            // Flashcards draw on every catalog and the filters can reach all of
            // them, so any failed dataset leaves the tab unable to present a
            // complete deck. The empty-filter state below stays reserved for the
            // case where data loaded fine and the user filtered everything out.
            dataUnavailableView
        case .loaded:
            if let card = manager.currentCard {
                cardView(for: card)
            } else {
                emptyStateView
            }
        }
    }

    var body: some View {
        NavigationStack {
            mainContent
        }
        .modifier(FlashcardsSheetModifier(
            showingFilter: $showingFilter,
            showingStudyContent: $showingStudyContent,
            showingSettings: $showingSettings,
            showingStats: $showingStats,
            filterRefreshID: $filterRefreshID,
            manager: manager,
            syncedStore: syncedStore
        ))
        .modifier(FlashcardsNavigationModifier(
            manager: manager,
            practiceTarget: $practiceTarget
        ))
        .onChange(of: manager.attempt) { _, _ in reviewNotice = nil }
        .onChange(of: manager.currentCard?.id) { _, _ in reviewNotice = nil }
        .onAppear {
            #if DEBUG
            if ScreenshotScenario.current == .flashcardCompleted,
               let currentCard = manager.currentCard {
                manager.learningModel.seedScreenshotCompletion(for: currentCard)
            } else if ScreenshotScenario.current == .progress {
                manager.learningModel.seedScreenshotProgress(for: manager.allCards)
            }
            #endif
        }
    }
}

// MARK: - View Modifiers for FlashcardsView

/// Modifier for sheet presentations
struct FlashcardsSheetModifier: ViewModifier {
    @Binding var showingFilter: Bool
    @Binding var showingStudyContent: Bool
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
            .sheet(isPresented: $showingStudyContent) {
                StudyContentView(settings: manager.settings)
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

/// The one path from deck settings to the flashcard deck. It sits on the
/// TabView, so a change made from either tab (Filters, Study Content) or by
/// an iCloud reload is applied whether or not Flashcards has been shown.
/// One logical change compares unequal once, so the deck is rebuilt once.
struct FlashcardDeckSyncModifier: ViewModifier {
    var settings: FlashcardSettings
    var manager: FlashcardManager?

    func body(content: Content) -> some View {
        content
            .onChange(of: settings.deckSettings) { _, _ in manager?.syncDeck() }
    }
}

/// Modifier for navigation jump handling
struct FlashcardsNavigationModifier: ViewModifier {
    var manager: FlashcardManager
    @Binding var practiceTarget: ReferenceItem?

    func body(content: Content) -> some View {
        content
            .onChange(of: practiceTarget, initial: true) { _, target in
                guard let target else { return }
                manager.practice(target)
                practiceTarget = nil
            }
    }
}

#Preview {
    ContentView(settings: FlashcardSettings())
}

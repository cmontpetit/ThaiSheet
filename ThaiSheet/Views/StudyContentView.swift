//
//  StudyContentView.swift
//  ThaiSheet
//

import SwiftUI

/// Study Content: what both tabs include. "Read Thai in 10 Days" material
/// (Off, through a chapter, or specific chapters) and whether uncommon
/// content shows. One sheet, opened from
/// either tab; quiz-only choices stay in the flashcard Filters.
struct StudyContentView: View {
    @Bindable var settings: FlashcardSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.thaiData) private var thaiData

    var body: some View {
        NavigationStack {
            Form {
                // Chapter controls need the mapping; the uncommon-content toggle does not.
                if thaiData.bookChapters != nil {
                    chapterSections
                }

                // One toggle for the two former flashcard filters. It drives both
                // keys (fc_uncommonConsonants, fc_uncommonVowels): nothing migrates.
                Section {
                    Toggle("Show uncommon consonants and vowels", isOn: Binding(
                        get: { settings.uncommonLetters },
                        set: { settings.setUncommonLetters($0) }
                    ))
                } header: {
                    Text("Uncommon content")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rare and obsolete consonants and vowels, such as ฃ, ฅ and ฦ. Applies to both tabs. Reference search still finds them.")
                        // Saved from the two former filters: the switch reads Off,
                        // but one kind still shows. Say so instead of resetting it.
                        // Two literals, not a ternary: a ternary of literals
                        // types as String, which Text would not localize.
                        if settings.uncommonVowels && !settings.uncommonConsonants {
                            Text("Your saved settings currently show uncommon vowels only.")
                        } else if settings.uncommonConsonants && !settings.uncommonVowels {
                            Text("Your saved settings currently show uncommon consonants only.")
                        }
                    }
                }
            }
            .navigationTitle("Study Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    /// How the book selection applies, chosen before the day(s)
    private enum BookMode: Hashable {
        case off, through, days
    }

    private var bookMode: Binding<BookMode> {
        Binding(
            get: {
                switch settings.bookSelection {
                case .off: .off
                case .through: .through
                case .days: .days
                }
            },
            set: { mode in
                // Carry the current day(s) across: Through keeps the last
                // selected day, Specific days starts from the chosen chapter.
                let current = settings.bookSelection
                switch mode {
                case .off:
                    settings.bookSelection = .off
                case .through:
                    if case .through = current { return }
                    settings.bookSelection = .through(current.legacyProgress ?? .day1)
                case .days:
                    if case .days = current { return }
                    settings.bookSelection = .days([current.legacyProgress ?? .day1])
                }
            }
        )
    }

    private var throughChapter: Binding<BookChapter> {
        Binding(
            get: { settings.bookSelection.legacyProgress ?? .day1 },
            set: { settings.bookSelection = .through($0) }
        )
    }

    private var selectedDays: Set<BookChapter> {
        if case .days(let days) = settings.bookSelection { days } else { [] }
    }

    /// Adds or removes a day; the last selected day stays (use Off instead).
    private func toggle(_ chapter: BookChapter) {
        var days = selectedDays
        if days.contains(chapter) {
            guard days.count > 1 else { return }
            days.remove(chapter)
        } else {
            days.insert(chapter)
        }
        settings.bookSelection = .days(days)
    }

    @ViewBuilder
    private var chapterSections: some View {
        Section {
            // Menus, not inline lists, for Off/Through: 11 rows would push
            // the toggle below the fold on iPhone.
            Picker("Show", selection: bookMode) {
                Text("Off").tag(BookMode.off)
                Text("Through a day").tag(BookMode.through)
                Text("Specific days").tag(BookMode.days)
            }
            .pickerStyle(.menu)

            switch settings.bookSelection {
            case .off:
                EmptyView()
            case .through:
                Picker("Up to", selection: throughChapter) {
                    ForEach(BookChapter.allCases, id: \.self) { chapter in
                        Text(chapter.title).tag(chapter)
                    }
                }
                .pickerStyle(.menu)
            case .days(let days):
                ForEach(BookChapter.allCases, id: \.self) { chapter in
                    let isSelected = days.contains(chapter)
                    Button {
                        toggle(chapter)
                    } label: {
                        HStack {
                            Text(chapter.dayTitle)
                                .foregroundStyle(.primary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    // Plain: a day reads as a row label, not a tinted link
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        } header: {
            Text(verbatim: "Read Thai in 10 Days")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                if case .days = settings.bookSelection {
                    Text("Both tabs show only what the selected days introduce. Reference search includes all chapters.")
                } else {
                    Text("Both tabs show only what the book has taught up to the chosen chapter. Reference search includes all chapters.")
                }
                Text("Chapters follow the 2nd edition by Arthit Juyaso (Bingo-Lingo). ThaiSheet is not affiliated with or endorsed by the author or publisher.")
            }
        }

        Section {
            Toggle("Not taught in the book", isOn: $settings.showNotInBook)
                .disabled(settings.bookSelection.isOff)
        } footer: {
            Text("Also show content no chapter teaches, such as the obsolete letters ฃ and ฅ.")
        }
    }
}

extension BookChapter {
    /// Picker label. DAY 5 is where the book's Intermission review checklist sits.
    var title: String {
        switch self {
        case .day5:
            String(localized: "Day 5 · Intermission", bundle: .appLanguage)
        case .lastDay:
            String(localized: "Last Day", bundle: .appLanguage)
        default:
            String(localized: "Day \(dayNumber)", bundle: .appLanguage)
        }
    }

    /// A day on its own, for Specific days: Day 5 alone is that day's
    /// material, not the Intermission review of everything so far.
    var dayTitle: String {
        switch self {
        case .lastDay:
            String(localized: "Last Day", bundle: .appLanguage)
        default:
            String(localized: "Day \(dayNumber)", bundle: .appLanguage)
        }
    }

    private var dayNumber: Int {
        BookChapter.allCases.firstIndex(of: self)! + 1
    }
}

/// Toolbar button that opens the Study Content sheet, the same in both tabs.
/// Filled whenever the sheet is hiding something: a chapter is selected, or
/// uncommon content is off.
struct StudyContentButton: View {
    let isActive: Bool
    let action: () -> Void

    init(settings: FlashcardSettings, map: BookChapterMap?, action: @escaping () -> Void) {
        self.isActive = Self.isActive(settings: settings, map: map)
        self.action = action
    }

    static func isActive(settings: FlashcardSettings, map: BookChapterMap?) -> Bool {
        BookScope(settings: settings, map: map).isActive || !settings.uncommonLetters
    }

    var body: some View {
        Button(action: action) {
            // Distinct from the Reference tab's book and the Filters funnel.
            Image(systemName: isActive ? "graduationcap.fill" : "graduationcap")
        }
        .accessibilityLabel(String(localized: "Study Content", bundle: .appLanguage))
        .accessibilityValue(isActive
            ? String(localized: "On", bundle: .appLanguage)
            : String(localized: "Off", bundle: .appLanguage))
    }
}

#Preview {
    StudyContentView(settings: FlashcardSettings())
}

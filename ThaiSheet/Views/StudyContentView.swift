//
//  StudyContentView.swift
//  ThaiSheet
//

import SwiftUI

/// Study Content: what both tabs include. "Read Thai in 10 Days" progress (up
/// to a chapter) and whether uncommon content shows. One sheet, opened from
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

    @ViewBuilder
    private var chapterSections: some View {
        // A menu, not an inline list: 11 rows would push the toggle
        // below the fold on iPhone.
        Section {
            Picker("Up to", selection: $settings.bookProgress) {
                Text("Off").tag(BookChapter?.none)
                ForEach(BookChapter.allCases, id: \.self) { chapter in
                    Text(chapter.title).tag(BookChapter?.some(chapter))
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(verbatim: "Read Thai in 10 Days")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Both tabs show only what the book has taught up to the chosen chapter. Reference search includes all chapters.")
                Text("Chapters follow the 2nd edition by Arthit Juyaso (Bingo-Lingo). ThaiSheet is not affiliated with or endorsed by the author or publisher.")
            }
        }

        Section {
            Toggle("Not taught in the book", isOn: $settings.showNotInBook)
                .disabled(settings.bookProgress == nil)
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

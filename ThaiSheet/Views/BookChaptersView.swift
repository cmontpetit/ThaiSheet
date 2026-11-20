//
//  BookChaptersView.swift
//  ThaiSheet
//

import SwiftUI

/// What both tabs include: "Read Thai in 10 Days" progress (up to a chapter)
/// and the uncommon-content toggles. One sheet, opened from either tab.
struct BookChaptersView: View {
    @Bindable var settings: FlashcardSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.thaiData) private var thaiData

    var body: some View {
        NavigationStack {
            Form {
                // Chapter controls need the mapping; the Content toggles do not.
                if thaiData.bookChapters != nil {
                    chapterSections
                }

                // These were flashcard filters. They keep their keys
                // (fc_uncommonConsonants, fc_uncommonVowels): nothing migrates.
                Section {
                    Toggle("Uncommon, rare & ancient", isOn: $settings.uncommonConsonants)
                    Toggle("Uncommon, rare & archaic", isOn: $settings.uncommonVowels)
                } header: {
                    Text("Content")
                } footer: {
                    Text("Consonants and vowels most learners can skip. Applies to both tabs. Reference search still finds them.")
                }
            }
            .navigationTitle("Book Chapters")
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
            Text("Both tabs show only what the book has taught up to the chosen chapter. Reference search includes all chapters.")
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

/// Toolbar button that opens the Book Chapters sheet. Filled while a scope is active.
struct BookChaptersButton: View {
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Not "book": that is the Reference tab's icon.
            Image(systemName: isActive ? "text.book.closed.fill" : "text.book.closed")
        }
        .accessibilityLabel(String(localized: "Book Chapters", bundle: .appLanguage))
        .accessibilityValue(isActive
            ? String(localized: "On", bundle: .appLanguage)
            : String(localized: "Off", bundle: .appLanguage))
    }
}

#Preview {
    BookChaptersView(settings: FlashcardSettings())
}

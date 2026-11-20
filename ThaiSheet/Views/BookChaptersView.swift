//
//  BookChaptersView.swift
//  ThaiSheet
//

import SwiftUI

/// "Read Thai in 10 Days" progress: limits both tabs to what the book has
/// taught up to the chosen chapter. One sheet, opened from either tab.
struct BookChaptersView: View {
    @Bindable var settings: FlashcardSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
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

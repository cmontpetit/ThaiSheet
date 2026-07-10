//
//  VowelRowView.swift
//  ThaiSheet
//

import SwiftUI

enum VowelFormType {
    case shortClosed, shortOpen, longClosed, longOpen

    var duration: String {
        switch self {
        case .shortClosed, .shortOpen: return "Short"
        case .longClosed, .longOpen: return "Long"
        }
    }

    var form: String {
        switch self {
        case .shortClosed, .longClosed: return "Closed"
        case .shortOpen, .longOpen: return "Open"
        }
    }
}

struct VowelHeaderView: View {
    /// When set, only that duration's columns are shown (full width)
    var visibleDuration: VowelCard.VowelDuration? = nil

    var body: some View {
        HStack(spacing: 0) {
            switch visibleDuration {
            case .short:
                durationHeader("SHORT", fullWidth: true)
                Divider()
                    .frame(height: 30)
                soundHeader
            case .long:
                durationHeader("LONG", fullWidth: true)
                Divider()
                    .frame(height: 30)
                soundHeader
            case nil:
                durationHeader("SHORT", fullWidth: false)
                Divider()
                    .frame(height: 30)
                soundHeader
                Divider()
                    .frame(height: 30)
                durationHeader("LONG", fullWidth: false)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private var soundHeader: some View {
        Text("Sound")
            .font(.caption)
            .fontWeight(.semibold)
            .frame(width: 60)
    }

    /// Full-width mode aligns the column labels leading, matching the cells
    private func durationHeader(_ title: LocalizedStringKey, fullWidth: Bool) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
            HStack(spacing: 0) {
                Text("Closed")
                    .font(.caption2)
                    .frame(maxWidth: .infinity, alignment: fullWidth ? .leading : .center)
                    .padding(.leading, fullWidth ? 24 : 0)
                Text("Open")
                    .font(.caption2)
                    .frame(maxWidth: .infinity, alignment: fullWidth ? .leading : .center)
                    .padding(.leading, fullWidth ? 24 : 0)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct VowelRowView: View {
    let vowel: Vowel
    var highlightedForm: String? = nil
    var searchQuery: String? = nil
    /// When set, only that duration's cells are shown (full width)
    var visibleDuration: VowelCard.VowelDuration? = nil
    var onPractice: ((String) -> Void)? = nil

    @Environment(\.audioPlayer) private var audioPlayer
    @Environment(\.learningModel) var learningModel
    @State private var selectedFormType: VowelFormType? = nil
    @State private var selectedText: String? = nil

    private func formMatchesSearch(_ form: String?) -> Bool {
        guard let form = form, let query = searchQuery, !query.isEmpty else { return true }
        return form.contains(query)
    }

    private var isHighlighted: Bool {
        guard let highlighted = highlightedForm else { return false }
        return vowel.allForms.contains(highlighted)
    }

    // Find a form that has a sound file (prefer visible forms, then closed forms)
    private var soundForm: (text: String, formType: VowelFormType)? {
        let candidates: [(String?, VowelFormType)]
        switch visibleDuration {
        case .short:
            candidates = [(vowel.short.closed, .shortClosed), (vowel.short.open, .shortOpen),
                          (vowel.long.closed, .longClosed), (vowel.long.open, .longOpen)]
        case .long:
            candidates = [(vowel.long.closed, .longClosed), (vowel.long.open, .longOpen),
                          (vowel.short.closed, .shortClosed), (vowel.short.open, .shortOpen)]
        case nil:
            candidates = [(vowel.long.closed, .longClosed), (vowel.short.closed, .shortClosed),
                          (vowel.long.open, .longOpen), (vowel.short.open, .shortOpen)]
        }
        return candidates
            .compactMap { text, formType in text.map { ($0, formType) } }
            .first { audioPlayer.hasSound(.vowel, key: $0.0) }
    }

    private var hasSound: Bool {
        soundForm != nil
    }

    private func showSheet(for text: String, formType: VowelFormType) {
        selectedFormType = formType
        selectedText = text
    }

    var body: some View {
        HStack(spacing: 0) {
            // Highlight indicator
            Circle()
                .fill(isHighlighted ? Color.accentColor : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.trailing, 4)

            switch visibleDuration {
            case .short:
                shortCells
                Divider()
                    .frame(height: 30)
                soundLabel
            case .long:
                longCells
                Divider()
                    .frame(height: 30)
                soundLabel
            case nil:
                shortCells
                Divider()
                    .frame(height: 30)
                soundLabel
                Divider()
                    .frame(height: 30)
                longCells
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(backgroundForRow)
        .sheet(
            isPresented: Binding(
                get: { selectedText != nil },
                set: { if !$0 { selectedFormType = nil; selectedText = nil } }
            )
        ) {
            if let text = selectedText, let formType = selectedFormType {
                ReferenceItemSheet(
                    title: ThaiDisplay.placeholder(text),
                    stage: learningModel.getProgress(forId: "vowel-\(text)").srsStage,
                    note: vowel.note(for: formType.duration, form: formType.form),
                    hasSound: audioPlayer.hasSound(.vowel, key: text),
                    onPlaySound: { audioPlayer.play(.vowel, key: text) },
                    onPractice: { onPractice?(text) }
                )
            }
        }
    }

    private var shortCells: some View {
        HStack(spacing: 0) {
            vowelCell(vowel.short.closed, formType: .shortClosed)
            vowelCell(vowel.short.open, formType: .shortOpen)
        }
        .frame(maxWidth: .infinity)
    }

    private var longCells: some View {
        HStack(spacing: 0) {
            vowelCell(vowel.long.closed, formType: .longClosed)
            vowelCell(vowel.long.open, formType: .longOpen)
        }
        .frame(maxWidth: .infinity)
    }

    // Romanization: tap plays the preferred form's sound, long press opens the sheet
    @ViewBuilder
    private var soundLabel: some View {
        let text = Text(vowel.sound)
            .font(.caption)
            .foregroundColor(hasSound ? .accentColor : .primary)
            .frame(width: 60)
            .frame(maxHeight: .infinity)
        if let form = soundForm {
            text.playableItem(
                label: "\(vowel.sound), \(form.text)",
                hasSound: true,
                onPlay: { audioPlayer.play(.vowel, key: form.text) },
                onDetails: { showSheet(for: form.text, formType: form.formType) }
            )
        } else {
            text
        }
    }

    private var backgroundForRow: Color {
        if isHighlighted {
            return Color.accentColor.opacity(0.1)
        } else if vowel.isUncommon {
            return Color.pink.opacity(0.1)
        }
        return Color.clear
    }

    /// Larger glyphs when a single duration has the full width
    private var formFont: Font {
        visibleDuration == nil ? .title2 : .system(size: 34)
    }

    /// Full-width mode reads like a table: content leads from the left edge
    private var cellAlignment: Alignment {
        visibleDuration == nil ? .center : .leading
    }

    private var cellLeadingPadding: CGFloat {
        visibleDuration == nil ? 0 : 24
    }

    // Tap plays this form's sound, long press opens the sheet
    @ViewBuilder
    private func vowelCell(_ text: String?, formType: VowelFormType) -> some View {
        if let text = text {
            let matches = formMatchesSearch(text)
            let isSelected = highlightedForm == text
            Text(ThaiDisplay.placeholder(text))
                .font(formFont)
                .foregroundColor(matches ? .primary : .secondary)
                .padding(.leading, cellLeadingPadding)
                .frame(maxWidth: .infinity, alignment: cellAlignment)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
                .playableItem(
                    label: text,
                    hasSound: audioPlayer.hasSound(.vowel, key: text),
                    onPlay: { audioPlayer.play(.vowel, key: text) },
                    onDetails: { showSheet(for: text, formType: formType) }
                )
        } else {
            Text("-")
                .font(formFont)
                .foregroundStyle(.quaternary)
                .padding(.leading, cellLeadingPadding)
                .frame(maxWidth: .infinity, alignment: cellAlignment)
        }
    }
}

#Preview {
    List {
        Section {
            VowelHeaderView()
                .listRowInsets(EdgeInsets())
        }
        VowelRowView(vowel: Vowel(
            short: VowelForm(closed: "กั-", open: "กะ"),
            long: VowelForm(closed: "กา-", open: "กา"),
            sounds: VowelSounds(en: "aa/ah"),
            notes: nil,
            usage: nil
        ))
        .listRowInsets(EdgeInsets())
        VowelRowView(vowel: Vowel(
            short: VowelForm(closed: "ก-", open: "โกะ"),
            long: VowelForm(closed: "โก-", open: "โก"),
            sounds: VowelSounds(en: "oh"),
            notes: VowelNotes(short_closed: "Unwritten/inherent vowel (e.g., กก = gok)", short_open: nil, long_closed: nil, long_open: nil),
            usage: nil
        ))
        .listRowInsets(EdgeInsets())
    }
    .listStyle(.plain)
}

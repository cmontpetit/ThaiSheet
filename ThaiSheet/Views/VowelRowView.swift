//
//  VowelRowView.swift
//  ThaiSheet
//

import SwiftUI

/// Duration × form pair identifying one of a vowel row's four cells,
/// expressed with the model's own enums (see VowelCard)
struct VowelFormVariant: Equatable {
    let duration: VowelCard.VowelDuration
    let form: VowelCard.VowelFormType

    static let shortClosed = VowelFormVariant(duration: .short, form: .closed)
    static let shortOpen = VowelFormVariant(duration: .short, form: .open)
    static let longClosed = VowelFormVariant(duration: .long, form: .closed)
    static let longOpen = VowelFormVariant(duration: .long, form: .open)
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
    @State private var selectedFormType: VowelFormVariant? = nil
    @State private var selectedText: String? = nil
    @ScaledMetric(relativeTo: .title2) private var singleDurationFormSize: CGFloat = 34

    private func formMatchesSearch(_ form: String?) -> Bool {
        guard let form = form, let query = searchQuery, !query.isEmpty else { return true }
        return form.contains(query)
    }

    private var isHighlighted: Bool {
        guard let highlighted = highlightedForm else { return false }
        return vowel.allForms.contains(highlighted)
    }

    // Find a form that has a sound file (prefer visible forms, then closed forms)
    private var soundForm: (
        text: String,
        formType: VowelFormVariant,
        pronunciation: ReferenceSampleWord
    )? {
        let candidates: [(String?, VowelFormVariant)]
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
        return candidates.compactMap { candidate -> (
            text: String,
            formType: VowelFormVariant,
            pronunciation: ReferenceSampleWord
        )? in
            let (text, formType) = candidate
            guard let text,
                  let pronunciation = pronunciation(for: formType),
                  audioPlayer.hasSound(.vowel, key: pronunciation.word) else { return nil }
            return (text, formType, pronunciation)
        }.first
    }

    private var hasSound: Bool {
        soundForm != nil
    }

    // One reveal per row: tapping any of its form cells reveals the shared reading
    private var concealID: String { FlashcardType.vowel.cardId(for: vowel.id) }

    private func showSheet(for text: String, formType: VowelFormVariant) {
        selectedFormType = formType
        selectedText = text
    }

    private func pronunciation(for formType: VowelFormVariant) -> ReferenceSampleWord? {
        vowel.pronunciation(for: formType.duration, form: formType.form)
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
                let pronunciation = pronunciation(for: formType)
                let sample = vowel.sample(
                    for: formType.duration.rawValue,
                    form: formType.form.rawValue
                )
                ReferenceItemSheet(
                    title: ThaiDisplay.placeholder(text),
                    romanization: vowel.sound,
                    stage: learningModel.getProgress(forId: FlashcardType.vowel.cardId(for: text)).srsStage,
                    note: vowel.note(for: formType.duration.rawValue, form: formType.form.rawValue),
                    pronunciationWord: pronunciation,
                    sampleWord: sample,
                    hasSound: pronunciation.map {
                        audioPlayer.hasSound(.vowel, key: $0.word)
                    } ?? false,
                    onPlaySound: {},
                    onPlayPronunciation: { audioPlayer.play(.vowel, key: $0.word) },
                    onPlaySampleWord: { audioPlayer.play(.sampleWord, key: $0.word) },
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
            .concealedReading(id: concealID)
            .frame(width: 60)
            .frame(maxHeight: .infinity)
        if let form = soundForm {
            text.playableItem(
                label: "\(vowel.sound), \(form.text)",
                hasSound: true,
                conceal: PracticeConceal(id: concealID, concealedLabel: form.text),
                onPlay: { audioPlayer.play(.vowel, key: form.pronunciation.word) },
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
        visibleDuration == nil ? .title2 : .system(size: singleDurationFormSize)
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
    private func vowelCell(_ text: String?, formType: VowelFormVariant) -> some View {
        if let text = text {
            let matches = formMatchesSearch(text)
            let isSelected = highlightedForm == text
            let pronunciation = pronunciation(for: formType)
            let hasSound = pronunciation.map {
                audioPlayer.hasSound(.vowel, key: $0.word)
            } ?? false
            Text(ThaiDisplay.placeholder(text))
                .font(formFont)
                .foregroundColor(matches ? .primary : .secondary)
                .padding(.leading, cellLeadingPadding)
                .frame(maxWidth: .infinity, alignment: cellAlignment)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
                .playableItem(
                    label: text,
                    hasSound: hasSound,
                    // Form cells share the row's single reading, so reveal (don't
                    // toggle) — a sibling tap must not hide the answer.
                    conceal: PracticeConceal(id: concealID, concealedLabel: text, revealOnly: true),
                    onPlay: {
                        guard let pronunciation else { return }
                        audioPlayer.play(.vowel, key: pronunciation.word)
                    },
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
            rowNote: nil,
            pronunciations: nil,
            samples: VowelSamples(
                short_closed: ReferenceSampleWord(word: "กัน"),
                short_open: ReferenceSampleWord(word: "กะ"),
                long_closed: ReferenceSampleWord(word: "การ"),
                long_open: ReferenceSampleWord(word: "กา")
            ),
            usage: nil
        ))
        .listRowInsets(EdgeInsets())
        VowelRowView(vowel: Vowel(
            short: VowelForm(closed: "ก-", open: "โกะ"),
            long: VowelForm(closed: "โก-", open: "โก"),
            sounds: VowelSounds(en: "oh"),
            notes: VowelNotesContainer(
                en: VowelNotes(short_closed: "Unwritten/inherent vowel (e.g., กก = gok)", short_open: nil, long_closed: nil, long_open: nil),
                fr: nil
            ),
            rowNote: nil,
            pronunciations: nil,
            samples: nil,
            usage: nil
        ))
        .listRowInsets(EdgeInsets())
    }
    .listStyle(.plain)
}

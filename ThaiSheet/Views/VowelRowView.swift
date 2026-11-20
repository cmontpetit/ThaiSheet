//
//  VowelRowView.swift
//  ThaiSheet
//

import SwiftUI

/// Duration × form pair identifying one of a vowel row's four cells,
/// expressed with the model's own enums (see VowelCard)
struct VowelFormVariant: Hashable {
    let duration: VowelCard.VowelDuration
    let form: VowelCard.VowelFormType

    static let shortClosed = VowelFormVariant(duration: .short, form: .closed)
    static let shortOpen = VowelFormVariant(duration: .short, form: .open)
    static let longClosed = VowelFormVariant(duration: .long, form: .closed)
    static let longOpen = VowelFormVariant(duration: .long, form: .open)

    static let all: [VowelFormVariant] = [.shortClosed, .shortOpen, .longClosed, .longOpen]
}

extension Vowel {
    /// The written form in one of the row's four cells, if the row has it.
    func form(_ variant: VowelFormVariant) -> String? {
        let pair = variant.duration == .short ? short : long
        return variant.form == .closed ? pair.closed : pair.open
    }
}

struct VowelReferenceWordSource {
    let role: ReferenceWordAudioRole
    let word: ReferenceSampleWord
    let soundType: SoundType
    let usesItemVoiceOverride: Bool
}

/// Resolves the semantic word roles before UI and playback closures are added.
/// A fallback sample represents the pronunciation once; only a dedicated
/// pronunciation creates a second, distinct Sample Word role.
func vowelReferenceWordSources(
    for vowel: Vowel,
    duration: VowelCard.VowelDuration,
    form: VowelCard.VowelFormType
) -> [VowelReferenceWordSource] {
    let dedicatedPronunciation = vowel.pronunciations?.value(
        for: duration.rawValue,
        form: form.rawValue
    )
    let sample = vowel.sample(for: duration.rawValue, form: form.rawValue)

    if let dedicatedPronunciation {
        var sources = [
            VowelReferenceWordSource(
                role: .pronunciationExample,
                word: dedicatedPronunciation,
                soundType: .vowel,
                usesItemVoiceOverride: true
            )
        ]
        if let sample {
            sources.append(
                VowelReferenceWordSource(
                    role: .sampleWord,
                    word: sample,
                    soundType: .sampleWord,
                    usesItemVoiceOverride: false
                )
            )
        }
        return sources
    }

    guard let sample else { return [] }
    return [
        VowelReferenceWordSource(
            role: .pronunciationExample,
            word: sample,
            soundType: .vowel,
            usesItemVoiceOverride: true
        )
    ]
}

struct VowelHeaderView: View {
    /// When set, only that duration's columns are shown (full width)
    var visibleDuration: VowelCard.VowelDuration? = nil
    /// False above vowel-plus-ending combinations, which have no Closed/Open forms
    var showsForms: Bool = true

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
        // Explicit color: inside a List section header, .secondary renders fainter
        .foregroundStyle(Color(.secondaryLabel))
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
            if showsForms {
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
        }
        .frame(maxWidth: .infinity)
    }
}

/// Section header for the vowel-plus-ending combinations (ไ◌, เ◌า, ◌ำ, ◌าย, …):
/// the explanation, then duration-only column headings (no Closed/Open)
struct VowelCombinationHeaderView: View {
    var visibleDuration: VowelCard.VowelDuration? = nil

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Vowel + ending")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.label))
                Text("These spellings include their ending: no final consonant follows. They count as live syllables for tone.")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            VowelHeaderView(visibleDuration: visibleDuration, showsForms: false)
            Divider()
        }
        .textCase(nil)
        // Opaque: the header pins while scrolling and rows pass beneath it
        .background(Color(.systemBackground))
        .listRowInsets(EdgeInsets())
    }
}

struct VowelRowView: View {
    let vowel: Vowel
    var highlightedForm: String? = nil
    var searchQuery: String? = nil
    /// When set, only that duration's cells are shown (full width)
    var visibleDuration: VowelCard.VowelDuration? = nil
    /// Forms the chapter scope hides: shown as empty cells, never played, never
    /// selected. Audio and details only ever use a visible form.
    var hiddenForms: Set<VowelFormVariant> = []
    @Environment(\.audioPlayer) private var audioPlayer
    @ScaledMetric(relativeTo: .title2) private var singleDurationFormSize: CGFloat = 34

    private func formMatchesSearch(_ form: String?) -> Bool {
        guard let form = form, let query = searchQuery, !query.isEmpty else { return true }
        return form.contains(query)
    }

    private var isHighlighted: Bool {
        guard let highlighted = highlightedForm else { return false }
        return vowel.allForms.contains(highlighted)
    }

    /// The forms the row displays, in the order the Sound cell prefers them:
    /// closed before open, long before short when both durations show. Only
    /// displayed forms qualify, so the Sound cell never plays or opens a form
    /// the duration chip or the chapter scope hides.
    static func soundCandidates(
        for vowel: Vowel,
        visibleDuration: VowelCard.VowelDuration?,
        hiddenForms: Set<VowelFormVariant>
    ) -> [(text: String, formType: VowelFormVariant)] {
        let order: [VowelFormVariant] = [.longClosed, .shortClosed, .longOpen, .shortOpen]
        return order.compactMap { variant in
            guard visibleDuration == nil || variant.duration == visibleDuration,
                  !hiddenForms.contains(variant),
                  let text = vowel.form(variant) else { return nil }
            return (text, variant)
        }
    }

    private var displayedCandidates: [(text: String, formType: VowelFormVariant)] {
        Self.soundCandidates(for: vowel, visibleDuration: visibleDuration, hiddenForms: hiddenForms)
    }

    // The first displayed form with a recording
    private var soundForm: (
        text: String,
        formType: VowelFormVariant,
        pronunciation: ReferenceSampleWord
    )? {
        displayedCandidates.compactMap { candidate -> (
            text: String,
            formType: VowelFormVariant,
            pronunciation: ReferenceSampleWord
        )? in
            guard let pronunciation = pronunciation(for: candidate.formType),
                  audioPlayer.hasSound(.vowel, key: pronunciation.word) else { return nil }
            return (candidate.text, candidate.formType, pronunciation)
        }.first
    }

    private var hasSound: Bool {
        soundForm != nil
    }

    /// The form the Sound column labels and opens details for: prefer one with
    /// audio, else any real form so a soundless row still conceals its reading,
    /// reveals on tap, and can open details.
    private var displayForm: (text: String, formType: VowelFormVariant)? {
        if let sound = soundForm { return (sound.text, sound.formType) }
        return displayedCandidates.first
    }

    // One reveal per row: tapping any of its form cells reveals the shared reading
    private var concealID: String { FlashcardType.vowel.cardId(for: vowel.id) }

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
    }

    private var shortCells: some View {
        cells([(vowel.short.closed, .shortClosed), (vowel.short.open, .shortOpen)])
    }

    private var longCells: some View {
        cells([(vowel.long.closed, .longClosed), (vowel.long.open, .longOpen)])
    }

    /// One duration's cells. Basic vowels keep the Closed/Open columns; a
    /// combination row has no such columns, so it shows only its real forms.
    private func cells(_ slots: [(text: String?, formType: VowelFormVariant)]) -> some View {
        let slots = slots.map { (text: hiddenForms.contains($0.formType) ? nil : $0.text, formType: $0.formType) }
        let shown = vowel.isCombination ? slots.filter { $0.text != nil } : slots
        return HStack(spacing: 0) {
            if shown.isEmpty {
                vowelCell(nil, formType: slots[0].formType)
            }
            ForEach(shown.indices, id: \.self) { index in
                vowelCell(shown[index].text, formType: shown[index].formType)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // Romanization: tap plays the preferred form's sound, long press opens the sheet
    @ViewBuilder
    private var soundLabel: some View {
        let text = Text(vowel.sound.romanized)
            .font(.caption)
            .foregroundColor(hasSound ? .accentColor : .primary)
            .concealedReading(id: concealID)
            .frame(width: 60)
            .frame(maxHeight: .infinity)
        if let form = displayForm {
            // concealedLabel is the Thai form (the question), never vowel.sound
            // (the answer), so soundless rows don't leak via VoiceOver either.
            text.playableItem(
                label: "\(vowel.sound.romanized), \(form.text)",
                hasSound: hasSound,
                conceal: PracticeConceal(id: concealID, concealedLabel: form.text),
                item: .vowel(id: vowel.id, variant: form.formType, text: form.text),
                onPlay: {
                    guard let sound = soundForm else { return }
                    audioPlayer.play(.vowel, key: sound.pronunciation.word, itemID: concealID)
                }
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
                    item: .vowel(id: vowel.id, variant: formType, text: text),
                    onPlay: {
                        guard let pronunciation else { return }
                        audioPlayer.play(.vowel, key: pronunciation.word, itemID: concealID)
                    }
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
            id: "a",
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
            id: "o",
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

//
//  ToneFinderView.swift
//  ThaiSheet
//

import SwiftUI

/// "Why this tone?": the learner types or pastes one syllable, the sheet
/// shows how it was read (initial, tone mark, ending, vowel length) and the
/// table row that gives its tone. Every fact can be set by hand, which is
/// also the way in when the text cannot be read.
struct ToneFinderView: View {
    /// Dismisses the sheet and highlights the deciding row in the Tones tables
    var onShowInTable: ((FlashcardType, String) -> Void)? = nil

    @Environment(\.thaiData) private var thaiData
    @Environment(\.audioPlayer) private var audioPlayer
    @Environment(\.dismiss) private var dismiss

    @State private var finder = ToneFinder()

    private var parser: SyllableParser {
        SyllableParser(
            consonants: thaiData.consonants,
            vowels: thaiData.vowels,
            clusters: thaiData.clusters,
            toneMarks: thaiData.toneMarks
        )
    }

    var body: some View {
        let resolution = finder.resolve(parser: parser, rules: thaiData.toneRules, marks: thaiData.toneMarks)
        NavigationStack {
            Form {
                inputSection(resolution)
                readAsSection(resolution)
                // Above the facts so the tone stays in view while they change
                resultSection(resolution)
                factsSection(resolution)
                examplesSection(resolution)
            }
            .navigationTitle("Why this tone?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Input

    private func inputSection(_ resolution: ToneFinder.Resolution) -> some View {
        Section {
            HStack(spacing: 12) {
                TextField("One Thai syllable", text: $finder.text)
                    .font(.title2)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                if !finder.text.isEmpty {
                    Button {
                        finder.text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Clear text"))
                }
                PasteButton(payloadType: String.self) { strings in
                    guard let pasted = strings.first else { return }
                    finder.text = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.capsule)
            }
        } footer: {
            if resolution.textNotRead {
                Text("ThaiSheet cannot read this as one syllable. Enter a single syllable, or choose its parts below.")
                    .foregroundStyle(.orange)
            } else {
                Text("Type or paste one syllable, or choose its parts below.")
            }
        }
    }

    // MARK: - Facts

    private func factsSection(_ resolution: ToneFinder.Resolution) -> some View {
        let reading = resolution.reading
        return Section {
            factRow(
                "Initial consonant",
                readAs: finder.chosenClass == nil ? reading?.initial : nil
            ) {
                Picker("Initial consonant", selection: classBinding(resolution)) {
                    ForEach(ConsonantClass.allCases, id: \.self) { consonantClass in
                        Text(consonantClass.displayName).tag(Optional(consonantClass))
                    }
                }
            }

            factRow("Tone Mark", readAs: nil) {
                Picker("Tone Mark", selection: markBinding(resolution)) {
                    Text("None").tag(Optional(ToneFinder.MarkChoice.none))
                    ForEach(thaiData.toneMarks) { mark in
                        Text(ThaiDisplay.placeholder(ToneMark.midConsonant + mark.mark))
                            .tag(Optional(ToneFinder.MarkChoice.mark(mark.mark)))
                    }
                }
            }

            if resolution.usesEndingAndDuration {
                factRow(
                    "Ending",
                    readAs: finder.chosenEnding == nil ? reading?.final : nil
                ) {
                    Picker("Ending", selection: endingBinding(resolution)) {
                        ForEach(ToneDerivation.Ending.allCases, id: \.self) { ending in
                            Text(localized(ending.rawValue)).tag(Optional(ending))
                        }
                    }
                }

                factRow(
                    "Vowel length",
                    readAs: finder.chosenDuration == nil && resolution.duration != nil
                        ? reading.map { ThaiDisplay.placeholder($0.form) }
                        : nil
                ) {
                    Picker("Vowel length", selection: durationBinding(resolution)) {
                        ForEach(VowelCard.VowelDuration.allCases, id: \.self) { duration in
                            Text(duration.label).tag(Optional(duration))
                        }
                    }
                }
            }
        } header: {
            Text("Syllable")
        } footer: {
            if resolution.usesEndingAndDuration {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live: ends in m, n, ng, y, w, or a long vowel. Dead: ends in k, t, p, or a short vowel.")
                    Text("\(vowelPlusEndingForms) count as live.")
                }
            } else {
                Text("A tone mark sets the tone together with the consonant class. The ending and the vowel length do not change it.")
            }
        }
    }

    /// The written vowel-plus-ending forms that are live without a final (ไ◌, ใ◌, เ◌า, ◌ำ)
    private var vowelPlusEndingForms: String {
        ["ไก", "ใก", "เกา", "กำ"].map { ThaiDisplay.placeholder($0) }.joined(separator: " ")
    }

    private func factRow<Control: View>(
        _ title: LocalizedStringKey,
        readAs: String?,
        @ViewBuilder control: () -> Control
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                if let readAs {
                    Text(verbatim: readAs)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            control()
                .pickerStyle(.segmented)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    private func classBinding(_ resolution: ToneFinder.Resolution) -> Binding<ConsonantClass?> {
        Binding(get: { resolution.consonantClass }, set: { finder.chosenClass = $0 })
    }

    private func markBinding(_ resolution: ToneFinder.Resolution) -> Binding<ToneFinder.MarkChoice?> {
        Binding(get: { resolution.mark }, set: { finder.chosenMark = $0 })
    }

    private func endingBinding(_ resolution: ToneFinder.Resolution) -> Binding<ToneDerivation.Ending?> {
        Binding(get: { resolution.ending }, set: { finder.chosenEnding = $0 })
    }

    private func durationBinding(_ resolution: ToneFinder.Resolution) -> Binding<VowelCard.VowelDuration?> {
        Binding(get: { resolution.duration }, set: { finder.chosenDuration = $0 })
    }

    // MARK: - Read as

    /// How the text was read, before the result, so a wrong reading can be
    /// caught before the tone is trusted
    @ViewBuilder
    private func readAsSection(_ resolution: ToneFinder.Resolution) -> some View {
        if let reading = resolution.reading {
            Section {
                readingParts(reading)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(resolution.readingNotes.enumerated()), id: \.offset) { _, note in
                        noteText(note)
                    }
                }
                .font(.subheadline)
                .padding(.vertical, 4)
            } header: {
                Text("Read as")
            }
        }
    }

    private func readingParts(_ reading: SyllableParser.Reading) -> some View {
        HStack(alignment: .top, spacing: 8) {
            readingPart(reading.initial, caption: "Initial")
            if let mark = reading.toneMark {
                partSeparator
                readingPart(markDisplay(mark), caption: "Tone Mark")
            }
            partSeparator
            readingPart(vowelDisplay(reading.form), caption: "Vowel")
            if let final = reading.final {
                partSeparator
                readingPart(final, caption: "Final")
            }
            if let silenced = reading.silenced {
                partSeparator
                readingPart(silenced + Self.thanthakhat, caption: "Silent")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func readingPart(_ text: String, caption: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(verbatim: text)
                .font(.title2)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var partSeparator: some View {
        Text(verbatim: "+")
            .font(.title3)
            .foregroundStyle(.tertiary)
            .padding(.top, 4)
            .accessibilityHidden(true)
    }

    private static let thanthakhat = "\u{0E4C}"

    /// A data form ("กา-") as shown: placeholder for ก, no final slot
    private func vowelDisplay(_ form: String) -> String {
        ThaiDisplay.placeholder(form.replacingOccurrences(of: "-", with: ""))
    }

    private func markDisplay(_ mark: String) -> String {
        ThaiDisplay.placeholder(ToneMark.midConsonant + mark)
    }

    @ViewBuilder
    private func noteText(_ note: ToneFinder.ReadingNote) -> some View {
        switch note {
        case .otherReading:
            Text("This spelling can also be read another way. Check the parts below.")
                .foregroundStyle(.orange)
        case .consonantClass(let letter, .low):
            Text("\(letter) is a low-class consonant.")
        case .consonantClass(let letter, .mid):
            Text("\(letter) is a mid-class consonant.")
        case .consonantClass(let letter, .high):
            Text("\(letter) is a high-class consonant.")
        case .silentHo(let following):
            Text("ห is silent and makes \(following) follow the high-class rules.")
        case .cluster(let letters, let classLetter):
            Text("\(letters) is a cluster: both letters are pronounced, and \(classLetter) sets the class.")
        case .irregularCluster(let letters, let classLetter):
            Text("\(letters) is read as one sound, and \(classLetter) sets the class.")
        case .clusterMaySplit:
            Text("Some words split these letters into two syllables (พลัง is พะ-ลัง). If yours does, enter only the syllable you want to check.")
                .foregroundStyle(.orange)
        case .toneMark(let mark):
            Text("\(markDisplay(mark)) is a tone mark: with the consonant class, it sets the tone.")
        case .unwrittenVowel:
            Text("No vowel is written: a short o is read between the consonants.")
        case .vowelWithEnding(let form):
            Text("\(vowelDisplay(form)) includes its ending, so the syllable is live.")
        case .vowelLength(let form, .short):
            Text("\(vowelDisplay(form)) is a short vowel.")
        case .vowelLength(let form, .long):
            Text("\(vowelDisplay(form)) is a long vowel.")
        case .vowelLengthNotShown(let form):
            Text("\(vowelDisplay(form)) does not show whether the vowel is short or long.")
        case .finalConsonant(let letters, let sound, .dead):
            Text("\(letters) is read \(sound.romanized): a dead ending.")
        case .finalConsonant(let letters, let sound, .live):
            Text("\(letters) is read \(sound.romanized): a live ending.")
        case .noFinal(.long):
            Text("No final consonant after a long vowel: a live ending.")
        case .noFinal(.short):
            Text("No final consonant after a short vowel: a dead ending.")
        case .silenced(let letters):
            Text("\(letters) is silent: \(markDisplay(Self.thanthakhat)) cancels it.")
        }
    }

    // MARK: - Result

    private func resultSection(_ resolution: ToneFinder.Resolution) -> some View {
        Section {
            if let derivation = resolution.derivation, let deciding = derivation.decidingStep {
                switch deciding {
                case .toneRule(let rule):
                    toneSummary(tone: rule.tone, lengthMatters: usesVowelDuration(derivation)) {
                        ToneRuleExpressionView(rule: rule)
                    }
                case .toneMarkRow(let row, let consonantClass):
                    if let entry = classEntry(of: row, for: consonantClass), let tone = entry.tone {
                        toneSummary(tone: tone) {
                            ToneMarkExpressionView(context: ToneMarkSheetContext(
                                mark: row.mark,
                                consonantClass: entry.className,
                                tone: tone
                            ))
                        }
                    }
                default:
                    EmptyView()
                }
            } else if let notice = resolution.notice {
                noticeText(notice)
            } else {
                Text("Choose the initial consonant, the tone mark and the ending to see the tone.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Tone")
        } footer: {
            if resolution.derivation != nil {
                Text("This is the tone the spelling gives. A few words are pronounced differently.")
            }
        }
    }

    /// The deciding table row drawn as the Reference draws it, then the tone's name
    private func toneSummary<Expression: View>(
        tone: String,
        lengthMatters: Bool = true,
        @ViewBuilder expression: () -> Expression
    ) -> some View {
        VStack(spacing: 8) {
            expression()
            Text(ThaiColors.toneName(tone))
                .font(.headline)
            if !lengthMatters {
                Text("Vowel length does not change the tone here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func noticeText(_ notice: ToneFinder.ResultNotice) -> some View {
        switch notice {
        case .chooseVowelLength:
            Text("Choose the vowel length. It decides the tone of this syllable.")
        case .markNotUsedWithClass:
            Text("This tone mark is not used with this consonant class.")
        case .noRule:
            Text("No tone rule covers this syllable.")
        }
    }

    // MARK: - Examples

    /// Sample words of the deciding row, with audio, and a way to the row itself
    @ViewBuilder
    private func examplesSection(_ resolution: ToneFinder.Resolution) -> some View {
        if let deciding = resolution.derivation?.decidingStep {
            Section {
                switch deciding {
                case .toneRule(let rule):
                    ForEach(Array((rule.samples ?? []).prefix(3)), id: \.id) { sample in
                        exampleButton(
                            ReferenceSampleWord(
                                word: sample.full,
                                romanization: sample.romanization,
                                meaning: sample.meaning
                            ),
                            soundType: .toneRule
                        )
                    }
                    showInTableButton(.toneRule, key: rule.id)
                case .toneMarkRow(let row, let consonantClass):
                    if let entry = classEntry(of: row, for: consonantClass) {
                        if let sample = row.sampleWord(for: entry.soundKey) {
                            exampleButton(sample, soundType: .sampleWord)
                        }
                        showInTableButton(.toneMark, key: entry.soundKey)
                    }
                default:
                    EmptyView()
                }
            } header: {
                Text("Examples")
            }
        }
    }

    private func classEntry(of row: ToneMark, for consonantClass: ConsonantClass) -> ToneMark.ClassEntry? {
        row.classEntries.first { $0.className.lowercased() == consonantClass.rawValue }
    }

    private func usesVowelDuration(_ derivation: ToneDerivation) -> Bool {
        derivation.steps.contains { step in
            if case .vowelDuration = step { return true }
            return false
        }
    }

    private func exampleButton(_ word: ReferenceSampleWord, soundType: SoundType) -> some View {
        let hasSound = audioPlayer.hasSound(soundType, key: word.word)
        return Button {
            audioPlayer.play(soundType, key: word.word)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: word.word)
                        .font(.title3)
                        .foregroundStyle(.primary)
                    if let romanization = word.romanization {
                        Text(verbatim: romanization.romanized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let meaning = word.localizedMeaning {
                        Text(verbatim: meaning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: hasSound ? "speaker.wave.2.fill" : "speaker.slash")
                    .foregroundStyle(hasSound ? Color.accentColor : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!hasSound)
    }

    @ViewBuilder
    private func showInTableButton(_ type: FlashcardType, key: String) -> some View {
        if let onShowInTable {
            Button {
                dismiss()
                onShowInTable(type, key)
            } label: {
                Label("Show in the table", systemImage: "tablecells")
            }
        }
    }

    private func localized(_ value: String) -> String {
        String(localized: String.LocalizationValue(value), bundle: .appLanguage)
    }
}

#Preview {
    ToneFinderView()
}

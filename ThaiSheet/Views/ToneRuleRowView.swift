//
//  ToneRuleRowView.swift
//  ThaiSheet
//

import SwiftUI

struct StyledConsonantClassText: View {
    let consonantClass: String
    var width: CGFloat? = nil
    var font: Font = .subheadline
    var verticalPadding: CGFloat = 6

    var body: some View {
        Text(localizedConsonantClass)
            .font(font)
            .frame(width: width)
            .padding(.horizontal, width == nil ? 10 : 0)
            .padding(.vertical, verticalPadding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var localizedConsonantClass: String {
        String(
            localized: String.LocalizationValue(consonantClass),
            bundle: .appLanguage
        )
    }

    private var backgroundColor: Color {
        ConsonantClass(rawValue: consonantClass.lowercased())?.color
            ?? Color(.systemGray5)
    }
}

struct StyledToneText: View {
    /// Tone data identifier from JSON (e.g. "Falling"); shown as the
    /// Paiboon-style diacritic on ◌ over a tone-colored chip, matching the
    /// transcriptions and flashcard answer buttons. Language-neutral.
    let tone: String
    var font: Font = .title2

    var body: some View {
        if tone.isEmpty {
            Text("")
        } else {
            Text(ThaiColors.toneDiacritic(tone))
                .font(font)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(ThaiColors.toneButtonBackground(tone))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel(ThaiColors.toneName(tone))
        }
    }
}

struct ToneRuleExpressionView: View {
    let rule: ToneRule
    @ScaledMetric(relativeTo: .largeTitle) private var toneIndicatorSize: CGFloat = 40

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                ruleInputs
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)

            toneResult
        }
        .font(.title3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var ruleInputs: some View {
        Group {
            StyledConsonantClassText(
                consonantClass: rule.initialConsonant,
                font: .headline
            )
            operatorSign("+")
            Text(localized(rule.vowelDuration))
            operatorSign("+")
            Text(localized(rule.end))
        }
    }

    private var toneResult: some View {
        StyledToneText(
            tone: rule.tone,
            font: .system(size: toneIndicatorSize, weight: .semibold)
        )
    }

    private var accessibilityLabel: String {
        "\(localized(rule.initialConsonant)) + \(localized(rule.vowelDuration)) + "
            + "\(localized(rule.end)) = \(ThaiColors.toneName(rule.tone))"
    }

    private func localized(_ value: String) -> String {
        String(localized: String.LocalizationValue(value), bundle: .appLanguage)
    }

    private func operatorSign(_ value: String) -> some View {
        Text(value)
            .foregroundStyle(.secondary)
    }
}

struct ToneRuleHeaderView: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Initial\nCons.")
                .multilineTextAlignment(.center)
                .frame(width: 60)

            Text("+")
                .foregroundStyle(.quaternary)
                .frame(width: 20)

            Text("Vowel\nDuration")
                .multilineTextAlignment(.center)
                .frame(width: 70)

            Text("+")
                .foregroundStyle(.quaternary)
                .frame(width: 20)

            Text("Live/Dead\nEnd")
                .multilineTextAlignment(.center)
                .frame(width: 80)

            Text("=")
                .foregroundStyle(.quaternary)
                .frame(width: 20)

            Text("Tone")
                .frame(width: 60)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
    }
}

struct ToneRuleRowView: View {
    let rule: ToneRule
    var isHighlighted: Bool = false
    var onPractice: (() -> Void)? = nil

    @Environment(\.audioPlayer) private var audioPlayer
    @Environment(\.learningModel) var learningModel
    @Environment(\.thaiData) private var thaiData
    @State private var showingSheet = false

    private var hasSound: Bool {
        guard let sample = rule.primarySample else { return false }
        return audioPlayer.hasSound(.toneRule, key: sample.full)
    }

    private var concealID: String { FlashcardType.toneRule.cardId(for: rule.id) }

    private var voiceOverride: (descriptor: VoiceOverrideDescriptor, preview: VoicePreviewTarget)? {
        thaiData.voiceOverrideCatalogEntry(for: concealID).map { ($0.descriptor, $0.canonicalPreview) }
    }

    private var ruleDisplay: String {
        let initial = String(
            localized: String.LocalizationValue(rule.initialConsonant),
            bundle: .appLanguage
        )
        let duration = String(
            localized: String.LocalizationValue(rule.vowelDuration),
            bundle: .appLanguage
        )
        let end = String(
            localized: String.LocalizationValue(rule.end),
            bundle: .appLanguage
        )
        return "\(initial) + \(duration) + \(end) = \(ThaiColors.toneName(rule.tone))"
    }

    private func referenceWord(from sample: ToneSample) -> ReferenceSampleWord {
        return ReferenceSampleWord(
            word: sample.full,
            romanization: sample.romanization,
            meaning: sample.meaning
        )
    }

    /// The first rule example is the audio demonstrated by the table row; the
    /// next sample is supplementary vocabulary. Present both as word roles rather
    /// than treating the primary example as an inherent sound of the rule.
    private var referenceWordAudios: [ReferenceWordAudio] {
        var audios: [ReferenceWordAudio] = []
        if let primary = rule.primarySample {
            audios.append(
                ReferenceWordAudio(
                    role: .primaryExample,
                    word: referenceWord(from: primary),
                    hasSound: audioPlayer.hasSound(.toneRule, key: primary.full),
                    onPlay: {
                        audioPlayer.play(.toneRule, key: primary.full, itemID: concealID)
                    }
                )
            )
        }
        if let additional = rule.samples?.dropFirst().first {
            audios.append(
                ReferenceWordAudio(
                    role: .additionalExample,
                    word: referenceWord(from: additional),
                    hasSound: audioPlayer.hasSound(.toneRule, key: additional.full),
                    onPlay: { audioPlayer.play(.toneRule, key: additional.full) }
                )
            )
        }
        return audios
    }

    /// The rule inputs alone (no resulting tone) — the concealed VoiceOver label.
    private var ruleInputsLabel: String {
        [rule.initialConsonant, rule.vowelDuration, rule.end]
            .map { String(localized: String.LocalizationValue($0), bundle: .appLanguage) }
            .joined(separator: ", ")
    }

    /// Spoken summary of the rule row, e.g. "Low, Short, Dead/None: High. คะ".
    private var ruleAccessibilityLabel: String {
        let tone = ThaiColors.toneName(rule.tone)
        if let sample = rule.primarySample {
            return "\(ruleInputsLabel): \(tone). \(sample.full)"
        }
        return "\(ruleInputsLabel): \(tone)"
    }

    /// Lowest stage among all sample cards for this rule
    private var lowestStage: SRSStage {
        guard let samples = rule.samples else { return .new }
        let stages = samples.map { sample in
            let cardId = FlashcardType.toneRule.cardId(for: ToneRuleCard.key(rule: rule, sample: sample))
            return learningModel.getProgress(forId: cardId).srsStage
        }
        return stages.min() ?? .new
    }

    var body: some View {
        HStack(spacing: 0) {
            // Highlight indicator
            Circle()
                .fill(isHighlighted ? Color.accentColor : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.trailing, 4)

            // Row content: tap plays the sound, long press opens the sheet
            HStack(spacing: 0) {
                StyledConsonantClassText(
                    consonantClass: rule.initialConsonant,
                    width: 60
                )

                Text("+")
                    .foregroundStyle(.quaternary)
                    .frame(width: 20)

                Text(String(localized: String.LocalizationValue(rule.vowelDuration), bundle: .appLanguage))
                    .frame(width: 70)

                Text("+")
                    .foregroundStyle(.quaternary)
                    .frame(width: 20)

                Text(String(localized: String.LocalizationValue(rule.end), bundle: .appLanguage))
                    .frame(width: 80)

                Text("=")
                    .foregroundStyle(.quaternary)
                    .frame(width: 20)

                StyledToneText(tone: rule.tone)
                    .foregroundColor(hasSound ? .accentColor : .primary)
                    .concealedReading(id: concealID)
                    .frame(width: 60)
            }
            .playableItem(
                label: ruleAccessibilityLabel,
                hasSound: hasSound && rule.primarySample != nil,
                conceal: PracticeConceal(id: concealID, concealedLabel: ruleInputsLabel),
                onPlay: {
                    if let sample = rule.primarySample {
                        audioPlayer.play(.toneRule, key: sample.full, itemID: concealID)
                    }
                },
                onDetails: { showingSheet = true }
            )
        }
        .font(.subheadline)
        .padding(.vertical, 4)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .background(isHighlighted ? Color.accentColor.opacity(0.1) : Color.clear)
        .sheet(isPresented: $showingSheet) {
            ReferenceItemSheet(
                title: ruleDisplay,
                toneRule: rule,
                usesCompactTitle: true,
                stage: lowestStage,
                note: rule.primarySample?.note?.localized,
                wordAudios: referenceWordAudios,
                onPractice: { onPractice?() },
                voiceOverride: voiceOverride
            )
        }
    }
}

#Preview {
    List {
        Section {
            ToneRuleHeaderView()
                .listRowInsets(EdgeInsets())
        }
        ToneRuleRowView(rule: ToneRule(
            initialConsonant: "Low",
            vowelDuration: "Short",
            end: "Dead/None",
            tone: "High",
            samples: [ToneSample(full: "คะ", focus: "คะ", note: nil)]
        ))
        .listRowInsets(EdgeInsets())
        ToneRuleRowView(rule: ToneRule(
            initialConsonant: "Mid",
            vowelDuration: "Any",
            end: "Live",
            tone: "Mid",
            samples: [ToneSample(full: "กา", focus: "กา", note: nil)]
        ))
        .listRowInsets(EdgeInsets())
        ToneRuleRowView(rule: ToneRule(
            initialConsonant: "High",
            vowelDuration: "Any",
            end: "Live",
            tone: "Rising",
            samples: [ToneSample(full: "ขา", focus: "ขา", note: LocalizedText(en: "Sample with a note", fr: nil))]
        ))
        .listRowInsets(EdgeInsets())
    }
    .listStyle(.plain)
}

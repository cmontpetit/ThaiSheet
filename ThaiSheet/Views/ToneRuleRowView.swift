//
//  ToneRuleRowView.swift
//  ThaiSheet
//

import SwiftUI

struct StyledToneText: View {
    /// Tone data identifier from JSON (e.g. "Falling"); shown as the
    /// Paiboon-style diacritic on ◌ over a tone-colored chip, matching the
    /// transcriptions and flashcard answer buttons. Language-neutral.
    let tone: String

    var body: some View {
        if tone.isEmpty {
            Text("")
        } else {
            Text(ThaiColors.toneDiacritic(tone))
                .font(.title2)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(ThaiColors.toneButtonBackground(tone))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel(ThaiColors.toneName(tone))
        }
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
    @State private var showingSheet = false

    private var hasSound: Bool {
        guard let sample = rule.primarySample else { return false }
        return audioPlayer.hasSound(.toneRule, key: sample.full)
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

    private var additionalSampleWord: ReferenceSampleWord? {
        guard let sample = rule.samples?.dropFirst().first else { return nil }
        return ReferenceSampleWord(
            word: sample.full,
            romanization: sample.romanization,
            meaning: sample.meaning
        )
    }

    /// Spoken summary of the rule row, e.g. "Low, Short, Dead/None: High. คะ"
    private var ruleAccessibilityLabel: String {
        let inputs = [rule.initialConsonant, rule.vowelDuration, rule.end]
            .map { String(localized: String.LocalizationValue($0), bundle: .appLanguage) }
            .joined(separator: ", ")
        let tone = ThaiColors.toneName(rule.tone)
        if let sample = rule.primarySample {
            return "\(inputs): \(tone). \(sample.full)"
        }
        return "\(inputs): \(tone)"
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
                Text(String(localized: String.LocalizationValue(rule.initialConsonant), bundle: .appLanguage))
                    .frame(width: 60)
                    .padding(.vertical, 6)
                    .background(rule.consonantColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

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
                    .frame(width: 60)
            }
            .playableItem(
                label: ruleAccessibilityLabel,
                hasSound: hasSound && rule.primarySample != nil,
                onPlay: {
                    if let sample = rule.primarySample {
                        audioPlayer.play(.toneRule, key: sample.full)
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
                subtitle: rule.primarySample?.full,
                toneIndicator: ThaiColors.toneDiacritic(rule.tone),
                usesCompactTitle: true,
                stage: lowestStage,
                note: rule.primarySample?.note?.localized,
                sampleWord: additionalSampleWord,
                hasSound: hasSound,
                onPlaySound: {
                    if let sample = rule.primarySample {
                        audioPlayer.play(.toneRule, key: sample.full)
                    }
                },
                onPlaySampleWord: { audioPlayer.play(.toneRule, key: $0.word) },
                onPractice: { onPractice?() }
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

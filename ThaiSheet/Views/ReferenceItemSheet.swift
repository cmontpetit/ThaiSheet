//
//  ReferenceItemSheet.swift
//  ThaiSheet
//

import SwiftUI

/// A reusable sheet for reference items showing stage, notes, and action buttons
struct ReferenceItemSheet: View {
    let title: String
    var romanization: String? = nil
    var subtitle: String? = nil
    var toneIndicator: String? = nil
    var toneIndicatorTone: String? = nil
    var consonantClassIndicator: String? = nil
    var toneRule: ToneRule? = nil
    var usesCompactTitle: Bool = false
    let stage: SRSStage
    let note: String?
    var pronunciationWord: ReferenceSampleWord? = nil
    var sampleWord: ReferenceSampleWord? = nil
    let hasSound: Bool
    let onPlaySound: () -> Void
    var soundActionLabel: LocalizedStringKey = "Play Sound"
    var onPlayPronunciation: (ReferenceSampleWord) -> Void = { _ in }
    var onPlaySampleWord: (ReferenceSampleWord) -> Void = { _ in }
    let onPractice: () -> Void

    @Environment(\.dismiss) var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 48
    @ScaledMetric(relativeTo: .largeTitle) private var titleFrameHeight: CGFloat = 86
    @ScaledMetric(relativeTo: .largeTitle) private var toneIndicatorSize: CGFloat = 40

    var body: some View {
        VStack(spacing: 18) {
            // Table item and its matching transcription or tone context
            VStack(spacing: 4) {
                Group {
                    if let toneRule {
                        ToneRuleExpressionView(rule: toneRule)
                            .padding(.horizontal)
                    } else {
                        Text(title)
                            .font(
                                usesCompactTitle
                                    ? .title2.weight(.semibold)
                                    : .system(size: titleSize)
                            )
                            .lineLimit(usesCompactTitle ? 3 : 1)
                            .minimumScaleFactor(0.45)
                    }
                }
                    .frame(height: titleFrameHeight)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .clipped()

                if let romanization, !romanization.isEmpty {
                    Text(romanization)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                if consonantClassIndicator != nil
                    || toneIndicator != nil
                    || toneIndicatorTone != nil {
                    HStack(spacing: 12) {
                        if let consonantClassIndicator {
                            StyledConsonantClassText(
                                consonantClass: consonantClassIndicator,
                                font: .title2.weight(.semibold),
                                verticalPadding: 8
                            )
                        }

                        if let toneIndicatorTone {
                            StyledToneText(
                                tone: toneIndicatorTone,
                                font: .system(size: toneIndicatorSize, weight: .semibold)
                            )
                        } else if let toneIndicator, !toneIndicator.isEmpty {
                            Text(toneIndicator)
                                .font(.system(size: toneIndicatorSize, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(minHeight: 48)
                }
            }

            // Stage indicator
            StageIndicatorView(stage: stage, isCapped: false)

            // Note (if any)
            if let note = note {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    if let pronunciationWord {
                        onPlayPronunciation(pronunciationWord)
                    } else {
                        onPlaySound()
                    }
                } label: {
                    HStack {
                        Image(systemName: hasSound ? "speaker.wave.2.fill" : "speaker.slash")
                        Text(soundActionLabel)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(hasSound ? Color.accentColor : Color.gray.opacity(0.3))
                    .foregroundColor(hasSound ? .white : .secondary)
                    .cornerRadius(12)
                }
                .disabled(!hasSound)

                Button {
                    dismiss()
                    onPractice()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.stack")
                        Text("Practice")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                if let exampleWord = sampleWord ?? pronunciationWord {
                    sampleWordButton(
                        exampleWord,
                        usesPronunciationAudio: exampleWord.word == pronunciationWord?.word
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .padding(.top, 18)
        .presentationDetents(
            pronunciationWord == nil
                && romanization == nil
                && subtitle == nil
                && toneIndicator == nil
                && toneIndicatorTone == nil
                && consonantClassIndicator == nil
                && toneRule == nil
                ? [.fraction(0.68), .large]
                : [.large]
        )
        .presentationDragIndicator(.visible)
    }

    private func sampleWordButton(
        _ sampleWord: ReferenceSampleWord,
        usesPronunciationAudio: Bool = false
    ) -> some View {
        Button {
            if usesPronunciationAudio {
                onPlayPronunciation(sampleWord)
            } else {
                onPlaySampleWord(sampleWord)
            }
        } label: {
            wordButtonLabel(sampleWord, title: "Sample Word", hasSound: true)
        }
        .buttonStyle(.plain)
    }

    private func wordButtonLabel(
        _ word: ReferenceSampleWord,
        title: LocalizedStringKey,
        hasSound: Bool
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(word.word)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                if let romanization = word.romanization {
                    Text(romanization)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let meaning = word.localizedMeaning {
                    Text(meaning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: hasSound ? "speaker.wave.2.fill" : "speaker.slash")
                .font(.title3)
                .foregroundStyle(hasSound ? Color.accentColor : Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    Text("Tap to show sheet")
        .sheet(isPresented: .constant(true)) {
            ReferenceItemSheet(
                title: "ก",
                romanization: "gaaw gài",
                stage: .apprentice1,
                note: "This is a sample note explaining the character.",
                pronunciationWord: ReferenceSampleWord(
                    word: "กัน",
                    romanization: "gan",
                    meaning: LocalizedText(en: "together", fr: "ensemble")
                ),
                sampleWord: ReferenceSampleWord(
                    word: "ไก่",
                    romanization: "gài",
                    meaning: LocalizedText(en: "chicken", fr: "poulet")
                ),
                hasSound: true,
                onPlaySound: {},
                onPlayPronunciation: { _ in },
                onPlaySampleWord: { _ in },
                onPractice: {}
            )
        }
}

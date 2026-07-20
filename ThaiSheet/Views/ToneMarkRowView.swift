//
//  ToneMarkRowView.swift
//  ThaiSheet
//

import SwiftUI

struct ToneMarkSheetContext {
    let mark: String
    let consonantClass: String
    let tone: String
}

struct ToneMarkExpressionView: View {
    let context: ToneMarkSheetContext
    @ScaledMetric(relativeTo: .largeTitle) private var markSize: CGFloat = 48
    @ScaledMetric(relativeTo: .largeTitle) private var toneIndicatorSize: CGFloat = 40

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(ThaiDisplay.placeholder(ToneMark.midConsonant + context.mark))
                    .font(.system(size: markSize))

                Text("+")
                    .foregroundStyle(.secondary)

                StyledConsonantClassText(
                    consonantClass: context.consonantClass,
                    font: .title2.weight(.semibold),
                    verticalPadding: 8
                )
            }

            StyledToneText(
                tone: context.tone,
                font: .system(size: toneIndicatorSize, weight: .semibold)
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let consonantClass = String(
            localized: String.LocalizationValue(context.consonantClass),
            bundle: .appLanguage
        )
        return "\(context.mark) + \(consonantClass): \(ThaiColors.toneName(context.tone))"
    }
}

struct ToneMarkHeaderView: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Tone Mark")
                .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 20)

            Text("On Low Cons.")
                .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 20)

            Text("On Mid Cons.")
                .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 20)

            Text("On High Cons.")
                .frame(maxWidth: .infinity)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
    }
}

struct ToneMarkRowView: View {
    let toneMark: ToneMark
    var isHighlighted: Bool = false
    var onPractice: ((String) -> Void)?

    @Environment(\.audioPlayer) private var audioPlayer
    @Environment(\.learningModel) var learningModel
    @Environment(\.thaiData) private var thaiData
    @State private var selectedDisplay: String? = nil

    private func stage(for display: String) -> SRSStage {
        learningModel.getProgress(forId: FlashcardType.toneMark.cardId(for: display)).srsStage
    }

    var body: some View {
        HStack(spacing: 0) {
            // Highlight indicator
            Circle()
                .fill(isHighlighted ? Color.accentColor : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.trailing, 4)

            // Tone mark on a dotted-circle placeholder (ก is the display stand-in)
            Text(ThaiDisplay.placeholder(ToneMark.midConsonant + toneMark.mark))
                .font(.title2)
                .frame(maxWidth: .infinity)

            ForEach(toneMark.classEntries) { entry in
                Divider()
                    .frame(height: 30)

                toneCell(entry)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .background(isHighlighted ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    @ViewBuilder
    private func toneCell(_ entry: ToneMark.ClassEntry) -> some View {
        if let tone = entry.tone {
            let hasSound = audioPlayer.hasSound(.toneMark, key: entry.soundKey)
            // Each class column is its own answer, so cells conceal individually
            let concealID = FlashcardType.toneMark.cardId(for: entry.soundKey)
            let voiceOverride = thaiData.voiceOverrideCatalogEntry(for: concealID)
                .map { ($0.descriptor, $0.canonicalPreview) }
            StyledToneText(tone: tone)
                .font(.subheadline)
                .concealedReading(id: concealID)
                .playableItem(
                    label: "\(entry.display), \(ThaiColors.toneName(tone))",
                    hasSound: hasSound,
                    conceal: PracticeConceal(id: concealID, concealedLabel: entry.display),
                    onPlay: { audioPlayer.play(.toneMark, key: entry.soundKey, itemID: concealID) },
                    onDetails: { selectedDisplay = entry.display }
                )
                .sheet(
                    isPresented: Binding(
                        get: { selectedDisplay == entry.display },
                        set: { if !$0 { selectedDisplay = nil } }
                    )
                ) {
                    let sampleWord = toneMark.sampleWord(for: entry.soundKey)
                    let wordAudios = sampleWord.map { sample in
                        [
                            ReferenceWordAudio(
                                role: .sampleWord,
                                word: sample,
                                hasSound: audioPlayer.hasSound(.sampleWord, key: sample.word),
                                onPlay: { audioPlayer.play(.sampleWord, key: sample.word) }
                            )
                        ]
                    } ?? []
                    ReferenceItemSheet(
                        title: ThaiDisplay.placeholder(ToneMark.midConsonant + toneMark.mark),
                        toneMarkContext: ToneMarkSheetContext(
                            mark: toneMark.mark,
                            consonantClass: entry.className,
                            tone: tone
                        ),
                        stage: stage(for: entry.soundKey),
                        note: nil,
                        primaryAudio: ReferencePrimaryAudio(
                            role: .tone,
                            hasSound: hasSound,
                            onPlay: {
                                audioPlayer.play(.toneMark, key: entry.soundKey, itemID: concealID)
                            }
                        ),
                        wordAudios: wordAudios,
                        onPractice: { onPractice?(entry.soundKey) },
                        voiceOverride: voiceOverride
                    )
                }
        } else {
            Text("—")
                .font(.subheadline)
                .foregroundStyle(.quaternary)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ToneMarkHeaderView()
        Divider()
        ToneMarkRowView(toneMark: ToneMark(
            mark: "\u{0E48}",
            onLow: "Falling",
            onMid: "Low",
            onHigh: "Low",
            samples: nil
        ))
        Divider()
        ToneMarkRowView(toneMark: ToneMark(
            mark: "\u{0E4A}",
            onLow: nil,
            onMid: "High",
            onHigh: nil,
            samples: nil
        ))
    }
}

//
//  ReferenceItemSheet.swift
//  ThaiSheet
//

import SwiftUI

/// A reusable sheet for reference items showing stage, notes, and action buttons
struct ReferenceItemSheet: View {
    let title: String
    var romanization: String? = nil
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

    var body: some View {
        VStack(spacing: 18) {
            // Table item and its matching romanization
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: titleSize))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .frame(height: titleFrameHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()

                if let romanization, !romanization.isEmpty {
                    Text(romanization)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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
                if let pronunciationWord {
                    pronunciationWordButton(pronunciationWord)
                } else {
                    Button {
                        onPlaySound()
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
                }

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

                if let sampleWord,
                   sampleWord.word != pronunciationWord?.word {
                    sampleWordButton(sampleWord)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .padding(.top, 18)
        .presentationDetents(
            pronunciationWord == nil && romanization == nil
                ? [.fraction(0.68), .large]
                : [.large]
        )
        .presentationDragIndicator(.visible)
    }

    private func pronunciationWordButton(_ word: ReferenceSampleWord) -> some View {
        Button {
            onPlayPronunciation(word)
        } label: {
            wordButtonLabel(word, title: "Pronunciation Example", hasSound: hasSound)
        }
        .buttonStyle(.plain)
        .disabled(!hasSound)
    }

    private func sampleWordButton(_ sampleWord: ReferenceSampleWord) -> some View {
        Button {
            onPlaySampleWord(sampleWord)
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

//
//  ReferenceItemSheet.swift
//  ThaiSheet
//

import SwiftUI

/// A reusable sheet for reference items showing stage, notes, and action buttons
struct ReferenceItemSheet: View {
    let title: String
    let stage: SRSStage
    let note: String?
    var sampleWord: ReferenceSampleWord? = nil
    let hasSound: Bool
    let onPlaySound: () -> Void
    var onPlaySampleWord: (ReferenceSampleWord) -> Void = { _ in }
    let onPractice: () -> Void

    @Environment(\.dismiss) var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 48
    @ScaledMetric(relativeTo: .largeTitle) private var titleFrameHeight: CGFloat = 86

    var body: some View {
        VStack(spacing: 18) {
            // Title
            Text(title)
                .font(.system(size: titleSize))
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .frame(height: titleFrameHeight)
                .frame(maxWidth: .infinity)
                .clipped()

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
                    onPlaySound()
                } label: {
                    HStack {
                        Image(systemName: hasSound ? "speaker.wave.2.fill" : "speaker.slash")
                        Text("Play Sound")
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

                if let sampleWord = sampleWord {
                    sampleWordButton(sampleWord)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .padding(.top, 18)
        .presentationDetents([.fraction(0.68), .large])
        .presentationDragIndicator(.visible)
    }

    private func sampleWordButton(_ sampleWord: ReferenceSampleWord) -> some View {
        Button {
            onPlaySampleWord(sampleWord)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sample Word")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(sampleWord.word)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    if let romanization = sampleWord.romanization {
                        Text(romanization)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let meaning = sampleWord.localizedMeaning {
                        Text(meaning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "speaker.wave.2.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    Text("Tap to show sheet")
        .sheet(isPresented: .constant(true)) {
            ReferenceItemSheet(
                title: "ก",
                stage: .apprentice1,
                note: "This is a sample note explaining the character.",
                sampleWord: ReferenceSampleWord(
                    word: "ไก่",
                    romanization: "gài",
                    meaning: LocalizedText(en: "chicken", fr: "poulet")
                ),
                hasSound: true,
                onPlaySound: {},
                onPlaySampleWord: { _ in },
                onPractice: {}
            )
        }
}

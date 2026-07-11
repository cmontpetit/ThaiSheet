//
//  ToneMarkRowView.swift
//  ThaiSheet
//

import SwiftUI

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
            StyledToneText(tone: tone)
                .font(.subheadline)
                .playableItem(
                    label: "\(entry.display), \(ThaiColors.toneName(tone))",
                    hasSound: hasSound,
                    onPlay: { audioPlayer.play(.toneMark, key: entry.soundKey) },
                    onDetails: { selectedDisplay = entry.display }
                )
                .sheet(
                    isPresented: Binding(
                        get: { selectedDisplay == entry.display },
                        set: { if !$0 { selectedDisplay = nil } }
                    )
                ) {
                    ReferenceItemSheet(
                        title: entry.display,
                        stage: stage(for: entry.soundKey),
                        note: nil,
                        sampleWord: toneMark.sampleWord(for: entry.soundKey),
                        hasSound: hasSound,
                        onPlaySound: { audioPlayer.play(.toneMark, key: entry.soundKey) },
                        onPlaySampleWord: { audioPlayer.play(.sampleWord, key: $0.word) },
                        onPractice: { onPractice?(entry.soundKey) }
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

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

            Text("On Mid/High Cons.")
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

    private var hasLowSound: Bool {
        audioPlayer.hasSound(.toneMark, key: toneMark.soundKeyLow)
    }

    private var hasMidHighSound: Bool {
        audioPlayer.hasSound(.toneMark, key: toneMark.soundKeyMidHigh)
    }

    private func stage(for display: String) -> SRSStage {
        learningModel.getProgress(forId: "toneMark-\(display)").srsStage
    }

    var body: some View {
        HStack(spacing: 0) {
            // Highlight indicator
            Circle()
                .fill(isHighlighted ? Color.accentColor : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.trailing, 4)

            // Tone mark on a dotted-circle placeholder
            Text(ThaiDisplay.placeholder(toneMark.withMidHighConsonant))
                .font(.title2)
                .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 30)

            toneCell(
                tone: toneMark.onLowConsonant,
                display: toneMark.withLowConsonant,
                soundKey: toneMark.soundKeyLow,
                hasSound: hasLowSound
            )
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 30)

            toneCell(
                tone: toneMark.onMidHighConsonant,
                display: toneMark.withMidHighConsonant,
                soundKey: toneMark.soundKeyMidHigh,
                hasSound: hasMidHighSound
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .background(isHighlighted ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    @ViewBuilder
    private func toneCell(tone: String, display: String, soundKey: String, hasSound: Bool) -> some View {
        if tone == "n/a" {
            Text("—")
                .font(.subheadline)
                .foregroundStyle(.quaternary)
        } else {
            Button {
                selectedDisplay = display
            } label: {
                StyledToneText(tone: tone)
                    .font(.subheadline)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(
                isPresented: Binding(
                    get: { selectedDisplay == display },
                    set: { if !$0 { selectedDisplay = nil } }
                )
            ) {
                ReferenceItemSheet(
                    title: display,
                    stage: stage(for: soundKey),
                    note: nil,
                    hasSound: hasSound,
                    onPlaySound: { audioPlayer.play(.toneMark, key: soundKey) },
                    onPractice: { onPractice?(soundKey) }
                )
            }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ToneMarkHeaderView()
        Divider()
        ToneMarkRowView(toneMark: ToneMark(
            mark: "",
            onLowConsonant: "Mid",
            onMidHighConsonant: "Mid"
        ))
        Divider()
        ToneMarkRowView(toneMark: ToneMark(
            mark: "\u{0E48}",
            onLowConsonant: "High",
            onMidHighConsonant: "Falling"
        ))
        Divider()
        ToneMarkRowView(toneMark: ToneMark(
            mark: "\u{0E4A}",
            onLowConsonant: "n/a",
            onMidHighConsonant: "High"
        ))
    }
}

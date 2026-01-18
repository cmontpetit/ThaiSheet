//
//  ToneMarkRowView.swift
//  ThaiSheet
//

import SwiftUI

struct ToneMarkHeaderView: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Low")
                .frame(maxWidth: .infinity)

            Text("Tone")
                .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 20)

            Text("Mid/High")
                .frame(maxWidth: .infinity)

            Text("Tone")
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

    @Environment(\.learningModel) var learningModel
    @State private var selectedDisplay: String? = nil

    private var hasLowSound: Bool {
        AudioPlayer.shared.hasToneMarkSound(for: toneMark.withLowConsonant)
    }

    private var hasMidHighSound: Bool {
        AudioPlayer.shared.hasToneMarkSound(for: toneMark.withMidHighConsonant)
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

            // Low consonant column
            toneMarkCell(
                display: toneMark.withLowConsonant,
                tone: toneMark.onLowConsonant,
                hasSound: hasLowSound,
                isNA: toneMark.onLowConsonant == "n/a"
            )
            .frame(maxWidth: .infinity)

            toneLabelCell(toneMark.onLowConsonant, display: toneMark.withLowConsonant, hasSound: hasLowSound)
                .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 30)

            // Mid/High consonant column
            toneMarkCell(
                display: toneMark.withMidHighConsonant,
                tone: toneMark.onMidHighConsonant,
                hasSound: hasMidHighSound,
                isNA: toneMark.onMidHighConsonant == "n/a"
            )
            .frame(maxWidth: .infinity)

            toneLabelCell(toneMark.onMidHighConsonant, display: toneMark.withMidHighConsonant, hasSound: hasMidHighSound)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .background(isHighlighted ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    @ViewBuilder
    private func toneMarkCell(display: String, tone: String, hasSound: Bool, isNA: Bool) -> some View {
        if isNA {
            Text("")
                .font(.title2)
        } else {
            Button {
                selectedDisplay = display
            } label: {
                Text(display)
                    .font(.title2)
                    .foregroundColor(.primary)
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
                    stage: stage(for: display),
                    note: nil,
                    hasSound: hasSound,
                    onPlaySound: { AudioPlayer.shared.playToneMarkSound(for: display) },
                    onPractice: { onPractice?(display) }
                )
            }
        }
    }

    @ViewBuilder
    private func toneLabelCell(_ tone: String, display: String, hasSound: Bool) -> some View {
        if tone == "n/a" {
            Text("")
                .font(.subheadline)
        } else {
            StyledToneText(tone: tone)
                .font(.subheadline)
                .foregroundColor(hasSound ? .accentColor : .secondary)
                .contentShape(Rectangle())
                .onTapGesture {
                    if hasSound {
                        AudioPlayer.shared.playToneMarkSound(for: display)
                    }
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

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

    private var hasLowSound: Bool {
        AudioPlayer.shared.hasToneMarkSound(for: toneMark.withLowConsonant)
    }

    private var hasMidHighSound: Bool {
        AudioPlayer.shared.hasToneMarkSound(for: toneMark.withMidHighConsonant)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Highlight indicator
            Circle()
                .fill(isHighlighted ? Color.accentColor : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.trailing, 4)

            // Low consonant column
            consonantCell(toneMark.withLowConsonant, isNA: toneMark.onLowConsonant == "n/a")
                .frame(maxWidth: .infinity)

            toneCell(toneMark.onLowConsonant, hasSound: hasLowSound) {
                AudioPlayer.shared.playToneMarkSound(for: toneMark.withLowConsonant)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 30)

            // Mid/High consonant column
            consonantCell(toneMark.withMidHighConsonant, isNA: toneMark.onMidHighConsonant == "n/a")
                .frame(maxWidth: .infinity)

            toneCell(toneMark.onMidHighConsonant, hasSound: hasMidHighSound) {
                AudioPlayer.shared.playToneMarkSound(for: toneMark.withMidHighConsonant)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .background(isHighlighted ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    @ViewBuilder
    private func consonantCell(_ text: String, isNA: Bool) -> some View {
        if isNA {
            Text("")
                .font(.title2)
        } else {
            Text(text)
                .font(.title2)
                .foregroundColor(.primary)
                .contentShape(Rectangle())
                .onTapGesture {
                    onPractice?(text)
                }
        }
    }

    @ViewBuilder
    private func toneCell(_ tone: String, hasSound: Bool, onTap: @escaping () -> Void) -> some View {
        if tone == "n/a" {
            Text("")
                .font(.subheadline)
        } else {
            StyledToneText(tone: tone)
                .font(.subheadline)
                .foregroundColor(hasSound ? .accentColor : .primary)
                .contentShape(Rectangle())
                .onTapGesture {
                    if hasSound {
                        onTap()
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

//
//  ToneRuleRowView.swift
//  ThaiSheet
//

import SwiftUI

struct StyledToneText: View {
    let tone: String

    var body: some View {
        if tone.isEmpty {
            Text("")
        } else {
            Text(String(tone.prefix(1))).fontWeight(.bold) +
            Text(String(tone.dropFirst())).foregroundColor(.secondary)
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

    private var hasSound: Bool {
        guard let sample = rule.primarySample else { return false }
        return AudioPlayer.shared.hasToneRuleSound(for: sample.full)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Highlight indicator
            Circle()
                .fill(isHighlighted ? Color.accentColor : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.trailing, 4)

            // Main content (tappable for practice)
            HStack(spacing: 0) {
                Text(rule.initialConsonant)
                    .frame(width: 60)
                    .padding(.vertical, 6)
                    .background(rule.consonantColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text("+")
                    .foregroundStyle(.quaternary)
                    .frame(width: 20)

                Text(rule.vowelDuration)
                    .frame(width: 70)

                Text("+")
                    .foregroundStyle(.quaternary)
                    .frame(width: 20)

                Text(rule.end)
                    .frame(width: 80)

                Text("=")
                    .foregroundStyle(.quaternary)
                    .frame(width: 20)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onPractice?()
            }

            // Tone column (tappable for sound)
            StyledToneText(tone: rule.tone)
                .foregroundColor(hasSound ? .accentColor : .primary)
                .frame(width: 60)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let sample = rule.primarySample, hasSound {
                        AudioPlayer.shared.playToneRuleSound(for: sample.full)
                    }
                }
        }
        .font(.subheadline)
        .padding(.vertical, 4)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .background(isHighlighted ? Color.accentColor.opacity(0.1) : Color.clear)
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
            samples: [ToneSample(full: "คะ", focus: "คะ")]
        ))
        .listRowInsets(EdgeInsets())
        ToneRuleRowView(rule: ToneRule(
            initialConsonant: "Mid",
            vowelDuration: "Any",
            end: "Live",
            tone: "Mid",
            samples: [ToneSample(full: "กา", focus: "กา")]
        ))
        .listRowInsets(EdgeInsets())
        ToneRuleRowView(rule: ToneRule(
            initialConsonant: "High",
            vowelDuration: "Any",
            end: "Live",
            tone: "Rising",
            samples: [ToneSample(full: "ขา", focus: "ขา")]
        ))
        .listRowInsets(EdgeInsets())
    }
    .listStyle(.plain)
}

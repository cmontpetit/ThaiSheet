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

    var body: some View {
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

            StyledToneText(tone: rule.tone)
                .frame(width: 60)
        }
        .font(.subheadline)
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
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
            tone: "High"
        ))
        .listRowInsets(EdgeInsets())
        ToneRuleRowView(rule: ToneRule(
            initialConsonant: "Mid",
            vowelDuration: "Any",
            end: "Live",
            tone: "Mid"
        ))
        .listRowInsets(EdgeInsets())
        ToneRuleRowView(rule: ToneRule(
            initialConsonant: "High",
            vowelDuration: "Any",
            end: "Live",
            tone: "Rising"
        ))
        .listRowInsets(EdgeInsets())
    }
    .listStyle(.plain)
}

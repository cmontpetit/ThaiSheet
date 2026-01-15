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

            Text("On Low Cons.")
                .frame(maxWidth: .infinity)

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
    let mark: ToneMark

    var body: some View {
        HStack(spacing: 0) {
            Text(mark.toneMark)
                .font(.title)
                .frame(maxWidth: .infinity)

            toneCell(mark.onLowConsonant)
                .frame(maxWidth: .infinity)

            toneCell(mark.onMidHighConsonant)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func toneCell(_ tone: String) -> some View {
        if tone == "n/a" {
            Text("n/a")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        } else {
            StyledToneText(tone: tone)
                .font(.subheadline)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ToneMarkHeaderView()
        Divider()
        ToneMarkRowView(mark: ToneMark(
            toneMark: "ก่",
            onLowConsonant: "High",
            onMidHighConsonant: "Falling"
        ))
        Divider()
        ToneMarkRowView(mark: ToneMark(
            toneMark: "ก๊",
            onLowConsonant: "n/a",
            onMidHighConsonant: "High"
        ))
    }
}

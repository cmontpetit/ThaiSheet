//
//  ToneLegendView.swift
//  ThaiSheet
//

import SwiftUI

/// Legend mapping the tone diacritics (◌̀ ◌ ◌́ ◌̂ ◌̌) to their localized
/// names; shown from the ⓘ button on the Tones reference section
struct ToneLegendView: View {
    private static let tones = ["Low", "Mid", "High", "Falling", "Rising"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Self.tones, id: \.self) { tone in
                HStack(spacing: 12) {
                    StyledToneText(tone: tone)
                    Text(ThaiColors.toneName(tone))
                        .font(.subheadline)
                }
            }
        }
        .padding()
    }
}

#Preview {
    ToneLegendView()
}

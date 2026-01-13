//
//  ConsonantRowView.swift
//  Aksorn
//

import SwiftUI

struct ClassIndicatorView: View {
    let activeClass: ConsonantClass

    var body: some View {
        VStack(spacing: 0) {
            ForEach(ConsonantClass.allCases.reversed(), id: \.self) { cls in
                ZStack {
                    Rectangle()
                        .fill(cls == activeClass ? cls.color : Color.clear)
                    if cls == activeClass {
                        Text(cls.label)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 20, height: 16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
        )
    }
}

struct ConsonantHeaderView: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Class")
                .frame(width: 20)

            Text("Char")
                .frame(width: 40)

            Text("Transcription")

            Spacer()

            HStack(spacing: 8) {
                Text("Initial")
                Text("Final")
            }
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
    }
}

struct ConsonantRowView: View {
    let consonant: Consonant

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ClassIndicatorView(activeClass: consonant.consonantClass)

            Text(consonant.character)
                .font(.largeTitle)

            Text(consonant.transcription)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 8) {
                    Text(consonant.initialSound)
                        .font(.subheadline)
                        .monospacedDigit()
                    Text(consonant.finalSound)
                        .font(.subheadline)
                        .monospacedDigit()
                }

                if consonant.usage != .common {
                    Text(consonant.usage.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}

#Preview {
    List {
        ConsonantRowView(consonant: Consonant(
            character: "ฮ",
            name: "ฮอ นกฮูก",
            transcription: "háawᴹ nòhkᴴ hùukᶠ",
            class: .low,
            usage: .uncommon,
            sounds: ConsonantSoundsContainer(en: ConsonantSounds(initial: "h-", final: "n/a"))
        ))
        ConsonantRowView(consonant: Consonant(
            character: "ก",
            name: "กอ ไก่",
            transcription: "gaawᴹ gaiᴸ",
            class: .mid,
            usage: .common,
            sounds: ConsonantSoundsContainer(en: ConsonantSounds(initial: "g-", final: "-k"))
        ))
        ConsonantRowView(consonant: Consonant(
            character: "ข",
            name: "ขอ ไข่",
            transcription: "khaawᴿ khaiᴸ",
            class: .high,
            usage: .common,
            sounds: ConsonantSoundsContainer(en: ConsonantSounds(initial: "kh-", final: "-k"))
        ))
    }
}

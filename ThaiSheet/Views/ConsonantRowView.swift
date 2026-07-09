//
//  ConsonantRowView.swift
//  ThaiSheet
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
            HStack(alignment: .center, spacing: 12) {
                Text("Cl.")
                    .fixedSize()
                    .frame(width: 20)

                Text("Char")
                    .frame(width: 40)

                Text("Transcription")

                Spacer()

                HStack(spacing: 8) {
                    Text("Initial")
                    Text("Final")
                }
                .frame(minWidth: 80)
            }
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
        .padding(.leading, 20) // Account for highlight indicator
        .padding(.trailing, 12)
        .background(Color(.systemBackground))
    }
}

struct ConsonantRowView: View {
    let consonant: Consonant
    var isHighlighted: Bool = false
    var onPractice: (() -> Void)? = nil

    @Environment(\.audioPlayer) private var audioPlayer
    @Environment(\.learningModel) var learningModel
    @State private var showingSheet = false

    private var hasSound: Bool {
        audioPlayer.hasSound(.consonant, key: consonant.character)
    }

    private var stage: SRSStage {
        learningModel.getProgress(forId: "consonant-\(consonant.id)").srsStage
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Highlight indicator
            Circle()
                .fill(isHighlighted ? Color.accentColor : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.trailing, 8)

            // Main row content (tappable for sheet)
            HStack(alignment: .center, spacing: 12) {
                ClassIndicatorView(activeClass: consonant.consonantClass)

                Text(consonant.character)
                    .font(.largeTitle)

                Text(consonant.transcription)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingSheet = true
            }

            // Sound area (tappable to play sound directly)
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 8) {
                    Text(consonant.initialSound)
                        .font(.subheadline)
                        .monospacedDigit()
                    Text(consonant.finalSound)
                        .font(.subheadline)
                        .monospacedDigit()
                }
                .foregroundColor(hasSound ? .accentColor : .primary)

                if consonant.usage != .common {
                    Text(consonant.usage.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 80)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                if hasSound {
                    audioPlayer.play(.consonant, key: consonant.character)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .background(isHighlighted ? Color.accentColor.opacity(0.1) : Color.clear)
        .sheet(isPresented: $showingSheet) {
            ReferenceItemSheet(
                title: consonant.character,
                stage: stage,
                note: nil,
                hasSound: hasSound,
                onPlaySound: { audioPlayer.play(.consonant, key: consonant.character) },
                onPractice: { onPractice?() }
            )
        }
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

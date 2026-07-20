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

    private var concealID: String { FlashcardType.consonant.cardId(for: consonant.id) }

    private var stage: SRSStage {
        learningModel.getProgress(forId: FlashcardType.consonant.cardId(for: consonant.id)).srsStage
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Highlight indicator
            Circle()
                .fill(isHighlighted ? Color.accentColor : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.trailing, 8)

            // Row content: tap plays the sound, long press opens the sheet
            HStack(alignment: .center, spacing: 12) {
                ClassIndicatorView(activeClass: consonant.consonantClass)

                Text(consonant.character)
                    .font(.largeTitle)

                Text(consonant.transcription)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .concealedReading(id: concealID)

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
                    .foregroundColor(hasSound ? .accentColor : .primary)
                    .concealedReading(id: concealID)

                    if consonant.usage != .common {
                        Text(consonant.usage.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 80)
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
            }
            .playableItem(
                // Full label carries the concealed answers (transcription + both
                // sounds) so a revealed VoiceOver user can check them.
                label: "\(consonant.character), \(consonant.transcription), \(consonant.initialSound), \(consonant.finalSound)",
                hasSound: hasSound,
                conceal: PracticeConceal(id: concealID, concealedLabel: consonant.character),
                onPlay: { audioPlayer.play(.consonant, key: consonant.character) },
                onDetails: { showingSheet = true }
            )
        }
        .padding(.vertical, 4)
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .background(isHighlighted ? Color.accentColor.opacity(0.1) : Color.clear)
        .sheet(isPresented: $showingSheet) {
            ReferenceItemSheet(
                title: consonant.character,
                romanization: consonant.transcription,
                stage: stage,
                note: nil,
                sampleWord: consonant.sampleWord,
                hasSound: hasSound,
                onPlaySound: { audioPlayer.play(.consonant, key: consonant.character) },
                soundActionLabel: "Say Name",
                onPlaySampleWord: { audioPlayer.play(.sampleWord, key: $0.word) },
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
            transcription: "haaw nók-hûuk",
            class: .low,
            usage: .uncommon,
            sounds: ConsonantSoundsContainer(en: ConsonantSounds(initial: "h-", final: "n/a")),
            sample: nil
        ))
        ConsonantRowView(consonant: Consonant(
            character: "ก",
            name: "กอ ไก่",
            transcription: "gaaw gài",
            class: .mid,
            usage: .common,
            sounds: ConsonantSoundsContainer(en: ConsonantSounds(initial: "g-", final: "-k")),
            sample: nil
        ))
        ConsonantRowView(consonant: Consonant(
            character: "ข",
            name: "ขอ ไข่",
            transcription: "khǎaw khài",
            class: .high,
            usage: .common,
            sounds: ConsonantSoundsContainer(en: ConsonantSounds(initial: "kh-", final: "-k")),
            sample: nil
        ))
    }
}

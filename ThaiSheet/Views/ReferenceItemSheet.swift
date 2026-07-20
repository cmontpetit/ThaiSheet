//
//  ReferenceItemSheet.swift
//  ThaiSheet
//

import SwiftUI

/// A reusable sheet for reference items showing stage, notes, and action buttons
struct ReferenceItemSheet: View {
    let title: String
    var romanization: String? = nil
    var subtitle: String? = nil
    var toneMarkContext: ToneMarkSheetContext? = nil
    var toneRule: ToneRule? = nil
    var usesCompactTitle: Bool = false
    let stage: SRSStage
    let note: String?
    var pronunciationWord: ReferenceSampleWord? = nil
    var sampleWord: ReferenceSampleWord? = nil
    let hasSound: Bool
    let onPlaySound: () -> Void
    var soundActionLabel: LocalizedStringKey = "Play Sound"
    var onPlayPronunciation: (ReferenceSampleWord) -> Void = { _ in }
    var onPlaySampleWord: (ReferenceSampleWord) -> Void = { _ in }
    let onPractice: () -> Void
    /// When set (and audio is in recorded mode), shows a per-item Voice override row.
    var voiceOverride: (descriptor: VoiceOverrideDescriptor, preview: VoicePreviewTarget)? = nil

    @Environment(\.dismiss) var dismiss
    @Environment(\.flashcardSettings) private var settings
    @State private var showingVoicePicker = false
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 48
    @ScaledMetric(relativeTo: .largeTitle) private var titleFrameHeight: CGFloat = 86
    @ScaledMetric(relativeTo: .largeTitle) private var toneHeaderFrameHeight: CGFloat = 124

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Table item and its matching transcription or tone context
                VStack(spacing: 4) {
                    Group {
                        if let toneRule {
                            ToneRuleExpressionView(rule: toneRule)
                                .padding(.horizontal)
                        } else if let toneMarkContext {
                            ToneMarkExpressionView(context: toneMarkContext)
                        } else {
                            Text(title)
                                .font(
                                    usesCompactTitle
                                        ? .title2.weight(.semibold)
                                        : .system(size: titleSize)
                                )
                                .lineLimit(usesCompactTitle ? 3 : 1)
                                .minimumScaleFactor(0.45)
                        }
                    }
                    .frame(
                        height: toneRule != nil || toneMarkContext != nil
                            ? toneHeaderFrameHeight
                            : titleFrameHeight
                    )
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                    if let romanization, !romanization.isEmpty {
                        Text(romanization)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.title2)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                }

                // Stage indicator
                StageIndicatorView(stage: stage, isCapped: false)

                // Note (if any)
                if let note = note {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        if let pronunciationWord {
                            onPlayPronunciation(pronunciationWord)
                        } else {
                            onPlaySound()
                        }
                    } label: {
                        HStack {
                            Image(
                                systemName: hasSound ? "speaker.wave.2.fill" : "speaker.slash")
                            Text(soundActionLabel)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hasSound ? Color.accentColor : Color.gray.opacity(0.3))
                        .foregroundColor(hasSound ? .white : .secondary)
                        .cornerRadius(12)
                    }
                    .disabled(!hasSound)

                    if let exampleWord = sampleWord ?? pronunciationWord {
                        sampleWordButton(
                            exampleWord,
                            usesPronunciationAudio: exampleWord.word == pronunciationWord?.word
                        )
                    }

                    Button {
                        dismiss()
                        onPractice()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.stack")
                            Text("Practice")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    // De-emphasized: the per-item voice override sits at the bottom.
                    if let voiceOverride, showsVoiceOverride {
                        Button {
                            showingVoicePicker = true
                        } label: {
                            HStack {
                                Text("Voice", bundle: .appLanguage)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(voiceStateLabel)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showingVoicePicker) {
                            VoiceOverridePicker(descriptor: voiceOverride.descriptor, preview: voiceOverride.preview)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.top, 18)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([preferredDetent, .large])
        .presentationDragIndicator(.visible)
    }

    /// Overrides need a settings store (absent only in previews).
    private var showsVoiceOverride: Bool { settings != nil }

    /// "Use Default · Matilda" (follows the default) vs "Google Kore · Override" (locked).
    private var voiceStateLabel: String {
        guard let voiceOverride else { return "" }
        if let override = settings?.voiceOverride(for: voiceOverride.descriptor.id) {
            return "\(override.displayName) · \(String(localized: "Override", bundle: .appLanguage))"
        }
        let def = settings?.recordedVoice ?? .matilda
        return "\(String(localized: "Use Default", bundle: .appLanguage)) · \(def.displayName)"
    }

    private var preferredDetent: PresentationDetent {
        sampleWord != nil || pronunciationWord != nil
            ? .fraction(0.78)
            : .fraction(0.68)
    }

    private func sampleWordButton(
        _ sampleWord: ReferenceSampleWord,
        usesPronunciationAudio: Bool = false
    ) -> some View {
        Button {
            if usesPronunciationAudio {
                onPlayPronunciation(sampleWord)
            } else {
                onPlaySampleWord(sampleWord)
            }
        } label: {
            wordButtonLabel(sampleWord, title: "Sample Word", hasSound: true)
        }
        .buttonStyle(.plain)
    }

    private func wordButtonLabel(
        _ word: ReferenceSampleWord,
        title: LocalizedStringKey,
        hasSound: Bool
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(word.word)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                if let romanization = word.romanization {
                    Text(romanization)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let meaning = word.localizedMeaning {
                    Text(meaning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: hasSound ? "speaker.wave.2.fill" : "speaker.slash")
                .font(.title3)
                .foregroundStyle(hasSound ? Color.accentColor : Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    Text("Tap to show sheet")
        .sheet(isPresented: .constant(true)) {
            ReferenceItemSheet(
                title: "ก",
                romanization: "gaaw gài",
                stage: .apprentice1,
                note: "This is a sample note explaining the character.",
                pronunciationWord: ReferenceSampleWord(
                    word: "กัน",
                    romanization: "gan",
                    meaning: LocalizedText(en: "together", fr: "ensemble")
                ),
                sampleWord: ReferenceSampleWord(
                    word: "ไก่",
                    romanization: "gài",
                    meaning: LocalizedText(en: "chicken", fr: "poulet")
                ),
                hasSound: true,
                onPlaySound: {},
                onPlayPronunciation: { _ in },
                onPlaySampleWord: { _ in },
                onPractice: {}
            )
        }
}

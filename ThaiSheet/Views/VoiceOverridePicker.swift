//
//  VoiceOverridePicker.swift
//  ThaiSheet
//

import SwiftUI

/// Picks the recorded voice for one reference item. "Use Default" follows the global
/// default; choosing a voice locks the item to it (even if it equals the current
/// default). Each voice can be previewed on the item's exact clip, and a voice missing
/// that clip is shown unavailable rather than silently falling back.
struct VoiceOverridePicker: View {
    let descriptor: VoiceOverrideDescriptor
    let preview: VoicePreviewTarget

    @Environment(\.flashcardSettings) private var settings
    @Environment(\.audioPlayer) private var audioPlayer
    @Environment(\.dismiss) private var dismiss

    private var current: RecordedVoice? { settings?.voiceOverride(for: descriptor.id) }
    private var defaultVoice: RecordedVoice { settings?.recordedVoice ?? .current }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    useDefaultRow
                    ForEach(RecordedVoice.allCases) { voice in
                        voiceRow(voice)
                    }
                } footer: {
                    Text("A voice you choose here stays selected even when you change the default voice.", bundle: .appLanguage)
                }
            }
            .navigationTitle(Text("Voice", bundle: .appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("Done", bundle: .appLanguage) }
                }
            }
        }
    }

    private var useDefaultRow: some View {
        Button {
            settings?.setVoiceOverride(nil, for: descriptor.id)
            dismiss()
        } label: {
            HStack {
                checkmark(current == nil)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use Default", bundle: .appLanguage)
                        .foregroundStyle(.primary)
                    Text(verbatim: "\(String(localized: "Currently", bundle: .appLanguage)) \(defaultVoice.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func voiceRow(_ voice: RecordedVoice) -> some View {
        let available = audioPlayer.hasRecordedSound(preview.soundType, key: preview.playbackKey, voice: voice)
        let selected = current == voice
        return HStack {
            Button {
                settings?.setVoiceOverride(voice, for: descriptor.id)
                dismiss()
            } label: {
                HStack {
                    checkmark(selected)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(voice.displayName)
                            .foregroundStyle(available || selected ? .primary : .secondary)
                        if !available {
                            Text(selected
                                 ? String(localized: "Unavailable — using Google Neural2-C", bundle: .appLanguage)
                                 : String(localized: "Falls back to Google Neural2-C", bundle: .appLanguage))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .disabled(!available && !selected)

            Spacer()

            Button {
                audioPlayer.play(preview.soundType, key: preview.playbackKey, itemID: nil, previewVoice: voice)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
            }
            .buttonStyle(.borderless)
            .disabled(!available)
            .accessibilityLabel("\(String(localized: "Preview", bundle: .appLanguage)) \(voice.displayName)")
        }
    }

    private func checkmark(_ on: Bool) -> some View {
        Image(systemName: "checkmark")
            .foregroundStyle(Color.accentColor)
            .opacity(on ? 1 : 0)
            .accessibilityHidden(!on)
    }
}

//
//  VoiceOverridesView.swift
//  ThaiSheet
//

import SwiftUI

/// Lists and manages every per-item recorded-voice override. Grouped by item type;
/// each row previews and re-opens the voice picker, swipe clears one, and Reset All
/// (with confirmation) clears them. Stale ids whose item no longer resolves are still
/// shown so the count matches and nothing is silently dropped.
struct VoiceOverridesView: View {
    @Environment(\.flashcardSettings) private var settings
    @Environment(\.thaiData) private var thaiData
    @Environment(\.audioPlayer) private var audioPlayer

    @State private var editing: EditContext?
    @State private var showingResetConfirm = false

    /// One resolved override row. `preview`/`descriptor` are nil for a stale id.
    private struct Row: Identifiable {
        let id: String
        let group: String
        let display: String
        let voice: RecordedVoice
        let entry: VoiceOverrideCatalogEntry?
    }

    private struct EditContext: Identifiable {
        let descriptor: VoiceOverrideDescriptor
        let preview: VoicePreviewTarget
        var id: String { descriptor.id }
    }

    // Fixed section order; "Unavailable" (stale) last.
    private let groupOrder = ["Consonants", "Vowels", "Clusters", "Tones", "Unavailable"]

    private var rows: [Row] {
        guard let settings else { return [] }
        return settings.overriddenItemIDs.compactMap { id in
            guard let voice = settings.voiceOverride(for: id) else { return nil }
            if let entry = thaiData.voiceOverrideCatalogEntry(for: id) {
                return Row(id: id, group: entry.descriptor.group, display: entry.descriptor.display, voice: voice, entry: entry)
            }
            return Row(id: id, group: "Unavailable", display: String(localized: "Unavailable reference item", bundle: .appLanguage), voice: voice, entry: nil)
        }
    }

    var body: some View {
        List {
            let rows = rows
            if rows.isEmpty {
                Section {
                    Text("No voice overrides. All reference items use the default recorded voice.", bundle: .appLanguage)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(groupOrder, id: \.self) { group in
                    let groupRows = rows.filter { $0.group == group }
                    if !groupRows.isEmpty {
                        Section(header: Text(localizedGroup(group))) {
                            ForEach(groupRows) { row in
                                rowView(row)
                            }
                        }
                    }
                }
                Section {
                    Button(role: .destructive) {
                        showingResetConfirm = true
                    } label: {
                        Text("Reset All Overrides", bundle: .appLanguage)
                    }
                }
            }
        }
        .navigationTitle(Text("Item voice overrides", bundle: .appLanguage))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { ctx in
            VoiceOverridePicker(descriptor: ctx.descriptor, preview: ctx.preview)
        }
        .confirmationDialog(
            Text("Reset voice overrides?", bundle: .appLanguage),
            isPresented: $showingResetConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                settings?.resetVoiceOverrides()
            } label: {
                Text("Reset All Overrides", bundle: .appLanguage)
            }
        } message: {
            Text("These items will return to using the default voice.", bundle: .appLanguage)
        }
    }

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        HStack {
            Button {
                if let entry = row.entry {
                    editing = EditContext(descriptor: entry.descriptor, preview: entry.canonicalPreview)
                }
            } label: {
                HStack {
                    Text(row.display).foregroundStyle(.primary)
                    Spacer()
                    Text(row.voice.displayName).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .disabled(row.entry == nil)

            if let entry = row.entry {
                Button {
                    audioPlayer.play(entry.canonicalPreview.soundType, key: entry.canonicalPreview.playbackKey, itemID: nil, previewVoice: row.voice)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(String(localized: "Preview", bundle: .appLanguage)) \(row.voice.displayName)")
            }
        }
        .swipeActions {
            Button(role: .destructive) {
                settings?.setVoiceOverride(nil, for: row.id)
            } label: {
                Text("Use Default", bundle: .appLanguage)
            }
        }
    }

    private func localizedGroup(_ group: String) -> String {
        String(localized: String.LocalizationValue(group), bundle: .appLanguage)
    }
}

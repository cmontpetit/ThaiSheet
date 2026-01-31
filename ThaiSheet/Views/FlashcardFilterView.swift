//
//  FlashcardFilterView.swift
//  ThaiSheet
//

import SwiftUI

struct FlashcardFilterView: View {
    @Bindable var settings: FlashcardSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Button("Select All") {
                            settings.selectAll()
                        }
                        .buttonStyle(.borderless)
                        .disabled(settings.isAllSelected)

                        Spacer()

                        Button("Deselect All") {
                            settings.deselectAll()
                        }
                        .buttonStyle(.borderless)
                        .disabled(settings.isNoneSelected)
                    }
                }

                // Consonants
                Section("Consonants") {
                    parentToggle(
                        title: "Consonants",
                        isOn: $settings.consonantsEnabled
                    )
                    if settings.consonantsEnabled {
                        childToggle(title: "High", isOn: $settings.highConsonants)
                        childToggle(title: "Mid", isOn: $settings.midConsonants)
                        childToggle(title: "Low", isOn: $settings.lowConsonants)
                        childToggle(title: "Uncommon, rare & ancient", isOn: $settings.uncommonConsonants)
                    }
                }

                // Vowels
                Section("Vowels") {
                    parentToggle(
                        title: "Vowels",
                        isOn: $settings.vowelsEnabled
                    )
                    if settings.vowelsEnabled {
                        childToggle(title: "Long", isOn: $settings.longVowels)
                        childToggle(title: "Short", isOn: $settings.shortVowels)
                        childToggle(title: "Uncommon, rare & archaic", isOn: $settings.uncommonVowels)
                    }
                }

                // Tones
                Section("Tones") {
                    parentToggle(
                        title: "Tones",
                        isOn: $settings.tonesEnabled
                    )
                    if settings.tonesEnabled {
                        childToggle(title: "High consonant rules", isOn: $settings.highToneRules)
                        childToggle(title: "Mid consonant rules", isOn: $settings.midToneRules)
                        childToggle(title: "Low consonant rules", isOn: $settings.lowToneRules)
                        childToggle(title: "Tone marks", isOn: $settings.toneMarks)
                    }
                }

                // Clusters
                Section("Clusters") {
                    parentToggle(
                        title: "Clusters",
                        isOn: $settings.clusters
                    )
                    if settings.clusters {
                        childToggle(title: "Smooth (กร-, ปล-, etc.)", isOn: $settings.smoothClusters)
                        childToggle(title: "Silent ห (หน-, หม-, etc.)", isOn: $settings.silentClusters)
                        childToggle(title: "Irregular (ทร-, จร-, etc.)", isOn: $settings.irregularClusters)
                    }
                }
            }
            .onChange(of: settings.consonantsEnabled) { _, newValue in
                if newValue {
                    settings.highConsonants = true
                    settings.midConsonants = true
                    settings.lowConsonants = true
                    settings.uncommonConsonants = true
                } else {
                    settings.highConsonants = false
                    settings.midConsonants = false
                    settings.lowConsonants = false
                    settings.uncommonConsonants = false
                }
            }
            .onChange(of: settings.vowelsEnabled) { _, newValue in
                if newValue {
                    settings.longVowels = true
                    settings.shortVowels = true
                    settings.uncommonVowels = true
                } else {
                    settings.longVowels = false
                    settings.shortVowels = false
                    settings.uncommonVowels = false
                }
            }
            .onChange(of: settings.tonesEnabled) { _, newValue in
                if newValue {
                    settings.highToneRules = true
                    settings.midToneRules = true
                    settings.lowToneRules = true
                    settings.toneMarks = true
                } else {
                    settings.highToneRules = false
                    settings.midToneRules = false
                    settings.lowToneRules = false
                    settings.toneMarks = false
                }
            }
            .onChange(of: settings.clusters) { _, newValue in
                if newValue {
                    settings.smoothClusters = true
                    settings.silentClusters = true
                    settings.irregularClusters = true
                } else {
                    settings.smoothClusters = false
                    settings.silentClusters = false
                    settings.irregularClusters = false
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Toggle Helpers

    /// Parent category toggle - controls visibility and enables/disables all children via .onChange
    @ViewBuilder
    private func parentToggle(
        title: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(title, isOn: isOn)
    }

    /// Child filter toggle
    @ViewBuilder
    private func childToggle(
        title: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(title, isOn: isOn)
            .padding(.leading, 16)
    }
}

#Preview {
    FlashcardFilterView(settings: FlashcardSettings())
}

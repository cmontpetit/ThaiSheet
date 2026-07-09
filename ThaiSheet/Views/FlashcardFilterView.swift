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
                    Toggle("Consonants", isOn: $settings.consonantsEnabled)
                    if settings.consonantsEnabled {
                        childToggle(title: "High", isOn: $settings.highConsonants)
                        childToggle(title: "Mid", isOn: $settings.midConsonants)
                        childToggle(title: "Low", isOn: $settings.lowConsonants)
                        childToggle(title: "Uncommon, rare & ancient", isOn: $settings.uncommonConsonants)
                    }
                }

                // Vowels
                Section("Vowels") {
                    Toggle("Vowels", isOn: $settings.vowelsEnabled)
                    if settings.vowelsEnabled {
                        childToggle(title: "Long", isOn: $settings.longVowels)
                        childToggle(title: "Short", isOn: $settings.shortVowels)
                        childToggle(title: "Uncommon, rare & archaic", isOn: $settings.uncommonVowels)
                    }
                }

                // Tones
                Section("Tones") {
                    Toggle("Tones", isOn: $settings.tonesEnabled)
                    if settings.tonesEnabled {
                        childToggle(title: "High consonant rules", isOn: $settings.highToneRules)
                        childToggle(title: "Mid consonant rules", isOn: $settings.midToneRules)
                        childToggle(title: "Low consonant rules", isOn: $settings.lowToneRules)
                        childToggle(title: "Tone marks", isOn: $settings.toneMarks)
                    }
                }

                // Clusters
                Section("Clusters") {
                    Toggle("Clusters", isOn: $settings.clusters)
                    if settings.clusters {
                        childToggle(title: "Smooth (กร-, ปล-, etc.)", isOn: $settings.smoothClusters)
                        childToggle(title: "Silent ห (หน-, หม-, etc.)", isOn: $settings.silentClusters)
                        childToggle(title: "Irregular (ทร-, จร-, etc.)", isOn: $settings.irregularClusters)
                    }
                }
            }
            .onChange(of: settings.consonantsEnabled) { _, newValue in
                setChildren([\.highConsonants, \.midConsonants, \.lowConsonants, \.uncommonConsonants], to: newValue)
            }
            .onChange(of: settings.vowelsEnabled) { _, newValue in
                setChildren([\.longVowels, \.shortVowels, \.uncommonVowels], to: newValue)
            }
            .onChange(of: settings.tonesEnabled) { _, newValue in
                setChildren([\.highToneRules, \.midToneRules, \.lowToneRules, \.toneMarks], to: newValue)
            }
            .onChange(of: settings.clusters) { _, newValue in
                setChildren([\.smoothClusters, \.silentClusters, \.irregularClusters], to: newValue)
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

    /// Cascade a parent toggle to its child filters
    private func setChildren(_ children: [ReferenceWritableKeyPath<FlashcardSettings, Bool>], to value: Bool) {
        for child in children {
            settings[keyPath: child] = value
        }
    }

    /// Child filter toggle
    @ViewBuilder
    private func childToggle(
        title: LocalizedStringKey,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(title, isOn: isOn)
            .padding(.leading, 16)
    }
}

#Preview {
    FlashcardFilterView(settings: FlashcardSettings())
}

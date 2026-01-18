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
                        .disabled(settings.isAllSelected)

                        Spacer()

                        Button("Reset") {
                            settings.resetToDefault()
                        }
                        .disabled(settings.isDefault)
                    }
                }

                // Consonants
                Section("Consonants") {
                    parentToggle(
                        title: "Consonants",
                        isOn: $settings.consonantsEnabled,
                        onEnable: {
                            settings.highConsonants = true
                            settings.midConsonants = true
                            settings.lowConsonants = true
                            settings.uncommonConsonants = true
                        },
                        onDisable: {
                            settings.highConsonants = false
                            settings.midConsonants = false
                            settings.lowConsonants = false
                            settings.uncommonConsonants = false
                        }
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
                        isOn: $settings.vowelsEnabled,
                        onEnable: {
                            settings.longVowels = true
                            settings.shortVowels = true
                        },
                        onDisable: {
                            settings.longVowels = false
                            settings.shortVowels = false
                        }
                    )
                    if settings.vowelsEnabled {
                        childToggle(title: "Long", isOn: $settings.longVowels)
                        childToggle(title: "Short", isOn: $settings.shortVowels)
                    }
                }

                // Tones
                Section("Tones") {
                    parentToggle(
                        title: "Tones",
                        isOn: $settings.tonesEnabled,
                        onEnable: {
                            settings.highToneRules = true
                            settings.midToneRules = true
                            settings.lowToneRules = true
                            settings.toneMarks = true
                        },
                        onDisable: {
                            settings.highToneRules = false
                            settings.midToneRules = false
                            settings.lowToneRules = false
                            settings.toneMarks = false
                        }
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
                        isOn: $settings.clusters,
                        onEnable: {
                            settings.smoothClusters = true
                            settings.silentClusters = true
                            settings.irregularClusters = true
                        },
                        onDisable: {
                            settings.smoothClusters = false
                            settings.silentClusters = false
                            settings.irregularClusters = false
                        }
                    )
                    if settings.clusters {
                        childToggle(title: "Smooth (กร-, ปล-, etc.)", isOn: $settings.smoothClusters)
                        childToggle(title: "Silent ห (หน-, หม-, etc.)", isOn: $settings.silentClusters)
                        childToggle(title: "Irregular (ทร-, จร-, etc.)", isOn: $settings.irregularClusters)
                    }
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

    /// Parent category toggle - enables/disables all children
    @ViewBuilder
    private func parentToggle(
        title: String,
        isOn: Binding<Bool>,
        onEnable: @escaping () -> Void,
        onDisable: @escaping () -> Void
    ) -> some View {
        Toggle(title, isOn: Binding(
            get: { isOn.wrappedValue },
            set: { newValue in
                isOn.wrappedValue = newValue
                if newValue {
                    onEnable()
                } else {
                    onDisable()
                }
            }
        ))
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

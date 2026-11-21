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
                Section {
                    Toggle("Consonants", isOn: categoryBinding(\.consonantsEnabled))
                    if settings.consonantsEnabled {
                        childToggle(title: "High", isOn: $settings.highConsonants)
                        childToggle(title: "Mid", isOn: $settings.midConsonants)
                        childToggle(title: "Low", isOn: $settings.lowConsonants)
                        childToggle(title: "Quiz consonant names", isOn: $settings.consonantNames)
                    }
                } header: {
                    Text("Consonants")
                } footer: {
                    if settings.consonantsEnabled {
                        Text("With names off, cards ask only the class and sounds. Each choice keeps its own progress.")
                    }
                }

                // Vowels
                Section("Vowels") {
                    Toggle("Vowels", isOn: categoryBinding(\.vowelsEnabled))
                    if settings.vowelsEnabled {
                        childToggle(title: "Long", isOn: $settings.longVowels)
                        childToggle(title: "Short", isOn: $settings.shortVowels)
                    }
                }

                // Tones
                Section("Tones") {
                    Toggle("Tones", isOn: categoryBinding(\.tonesEnabled))
                    if settings.tonesEnabled {
                        childToggle(title: "High consonant rules", isOn: $settings.highToneRules)
                        childToggle(title: "Mid consonant rules", isOn: $settings.midToneRules)
                        childToggle(title: "Low consonant rules", isOn: $settings.lowToneRules)
                        childToggle(title: "Tone marks", isOn: $settings.toneMarks)
                    }
                }

                // Clusters
                Section("Clusters") {
                    Toggle("Clusters", isOn: categoryBinding(\.clusters))
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

    /// A parent toggle that sets its child filters in the same change
    private func categoryBinding(_ category: ReferenceWritableKeyPath<FlashcardSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: category] },
            set: { settings.setCategory(category, to: $0) }
        )
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

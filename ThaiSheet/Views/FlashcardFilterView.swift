//
//  FlashcardFilterView.swift
//  ThaiSheet
//

import SwiftUI

struct FlashcardFilterView: View {
    @Bindable var settings: FlashcardSettings
    @Environment(\.dismiss) private var dismiss
    @State private var refreshID = UUID()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Button("Select All") {
                            settings.selectAll()
                            refreshID = UUID()
                        }
                        .disabled(settings.isAllSelected)

                        Spacer()

                        Button("Reset") {
                            settings.resetToDefault()
                            refreshID = UUID()
                        }
                        .disabled(settings.isDefault)
                    }
                }

                Section("Consonants") {
                    filterToggle(
                        title: "High consonants",
                        isOn: $settings.highConsonants
                    )
                    filterToggle(
                        title: "Mid consonants",
                        isOn: $settings.midConsonants
                    )
                    filterToggle(
                        title: "Low consonants",
                        isOn: $settings.lowConsonants
                    )
                    filterToggle(
                        title: "Uncommon, rare & ancient",
                        isOn: $settings.uncommonConsonants
                    )
                }

                Section("Vowels") {
                    filterToggle(
                        title: "Long vowels",
                        isOn: $settings.longVowels
                    )
                    filterToggle(
                        title: "Short vowels",
                        isOn: $settings.shortVowels
                    )
                }

                Section("Tones") {
                    filterToggle(
                        title: "High consonant tone rules",
                        isOn: $settings.highToneRules
                    )
                    filterToggle(
                        title: "Mid consonant tone rules",
                        isOn: $settings.midToneRules
                    )
                    filterToggle(
                        title: "Low consonant tone rules",
                        isOn: $settings.lowToneRules
                    )
                    filterToggle(
                        title: "Tone marks",
                        isOn: $settings.toneMarks
                    )
                }
            }
            .id(refreshID)
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

    @ViewBuilder
    private func filterToggle(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: Binding(
            get: { isOn.wrappedValue },
            set: { newValue in
                // Prevent disabling if it's the last enabled option
                if !newValue && settings.isLastEnabled && isOn.wrappedValue {
                    return
                }
                isOn.wrappedValue = newValue
            }
        ))
    }
}

#Preview {
    FlashcardFilterView(settings: FlashcardSettings())
}

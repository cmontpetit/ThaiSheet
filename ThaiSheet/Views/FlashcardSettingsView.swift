//
//  FlashcardSettingsView.swift
//  ThaiSheet
//

import SwiftUI

struct FlashcardSettingsView: View {
    @Bindable var settings: FlashcardSettings
    @Environment(\.dismiss) private var dismiss
    @State private var refreshID = UUID()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Smart Selection", isOn: $settings.useIntelligentSelection)
                } header: {
                    Text("Card Selection Mode")
                } footer: {
                    Text(settings.useIntelligentSelection
                        ? "Cards you struggle with appear more often."
                        : "Cards appear in sequential order.")
                }

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

                Section {
                    settingToggle(
                        title: "High consonants",
                        isOn: $settings.highConsonants
                    )
                    settingToggle(
                        title: "Mid consonants",
                        isOn: $settings.midConsonants
                    )
                    settingToggle(
                        title: "Low consonants",
                        isOn: $settings.lowConsonants
                    )
                    settingToggle(
                        title: "Uncommon, rare & ancient",
                        isOn: $settings.uncommonConsonants
                    )
                } header: {
                    Text("Consonants")
                }

                Section {
                    settingToggle(
                        title: "Long vowels",
                        isOn: $settings.longVowels
                    )
                    settingToggle(
                        title: "Short vowels",
                        isOn: $settings.shortVowels
                    )
                } header: {
                    Text("Vowels")
                }

                Section {
                    settingToggle(
                        title: "High consonant tone rules",
                        isOn: $settings.highToneRules
                    )
                    settingToggle(
                        title: "Mid consonant tone rules",
                        isOn: $settings.midToneRules
                    )
                    settingToggle(
                        title: "Low consonant tone rules",
                        isOn: $settings.lowToneRules
                    )
                    settingToggle(
                        title: "Tone marks",
                        isOn: $settings.toneMarks
                    )
                } header: {
                    Text("Tones")
                }
            }
            .id(refreshID)
            .navigationTitle("Flashcard Settings")
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
    private func settingToggle(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: Binding(
            get: { isOn.wrappedValue },
            set: { newValue in
                // Prevent disabling if it's the last enabled option
                if !newValue && settings.isLastEnabled && isOn.wrappedValue {
                    // Don't allow turning off - it's the last one
                    return
                }
                isOn.wrappedValue = newValue
            }
        ))
    }
}

#Preview {
    FlashcardSettingsView(settings: FlashcardSettings())
}

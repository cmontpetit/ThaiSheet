//
//  FlashcardSettingsView.swift
//  ThaiSheet
//

import SwiftUI

struct FlashcardSettingsView: View {
    @Bindable var settings: FlashcardSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    strategyOption(
                        title: "Wanikani-style SRS",
                        description: "Prioritizes cards due for review based on your progress. Uses spaced repetition to optimize learning.",
                        isSelected: settings.useIntelligentSelection
                    ) {
                        settings.useIntelligentSelection = true
                    }

                    strategyOption(
                        title: "Sequential",
                        description: "Shows cards in fixed order. Good for systematic review of all cards.",
                        isSelected: !settings.useIntelligentSelection
                    ) {
                        settings.useIntelligentSelection = false
                    }
                } header: {
                    Text("Learning Strategy")
                }
            }
            .navigationTitle("Settings")
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
    private func strategyOption(
        title: String,
        description: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FlashcardSettingsView(settings: FlashcardSettings())
}

//
//  SRSStatsView.swift
//  ThaiSheet
//

import SwiftUI

struct SRSStatsView: View {
    let learningModel: LearningModel
    let filteredCards: [FlashcardItem]
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Stage distribution section
                Section("Stage Distribution") {
                    stageDistributionChart
                }

                // Summary stats section
                Section("Summary") {
                    summaryStats
                }

                // Breakdown by type section
                Section("By Card Type") {
                    cardTypeBreakdown
                }

                // Reset section
                Section {
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset All Progress")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Reset All Progress?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    learningModel.resetAllProgress()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset all SRS stages to New. This cannot be undone.")
            }
        }
    }

    // MARK: - Stage Distribution Chart

    private var stageDistributionChart: some View {
        let stageCounts = calculateStageCounts()
        let maxCount = stageCounts.values.max() ?? 1

        return VStack(alignment: .leading, spacing: 8) {
            ForEach(SRSStage.allCases, id: \.rawValue) { stage in
                let count = stageCounts[stage] ?? 0
                HStack(spacing: 8) {
                    Text(stage.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)

                    GeometryReader { geometry in
                        let barWidth = maxCount > 0
                            ? geometry.size.width * CGFloat(count) / CGFloat(maxCount)
                            : 0

                        RoundedRectangle(cornerRadius: 3)
                            .fill(stageColor(stage))
                            .frame(width: max(barWidth, count > 0 ? 4 : 0), height: 16)
                    }
                    .frame(height: 16)

                    Text("\(count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func stageColor(_ stage: SRSStage) -> Color {
        switch stage {
        case .new: return .gray
        case .learning1, .learning2: return .blue
        case .apprentice1, .apprentice2: return .pink
        case .familiar1, .familiar2: return .purple
        case .confident: return .indigo
        case .mastered: return .yellow
        }
    }

    // MARK: - Summary Stats

    private var summaryStats: some View {
        let dueCount = learningModel.dueCardCount(in: filteredCards)
        let masteredCount = learningModel.masteredCardCount(in: filteredCards)
        let totalCards = filteredCards.count
        let masteredPercent = totalCards > 0 ? Int(Double(masteredCount) / Double(totalCards) * 100) : 0
        let successRate = learningModel.overallSuccessRate

        return VStack(spacing: 12) {
            HStack {
                StatBox(title: "Due Now", value: "\(dueCount)", color: .orange)
                StatBox(title: "Total Cards", value: "\(totalCards)", color: .blue)
            }
            HStack {
                StatBox(title: "Mastered", value: "\(masteredCount) (\(masteredPercent)%)", color: .yellow)
                StatBox(
                    title: "Success Rate",
                    value: successRate.map { "\(Int($0 * 100))%" } ?? "—",
                    color: .green
                )
            }
            HStack {
                StatBox(title: "Total Reviews", value: "\(learningModel.totalReviews)", color: .purple)
                StatBox(title: "Cards Reviewed", value: "\(learningModel.reviewedCardCount)", color: .indigo)
            }
        }
    }

    // MARK: - Card Type Breakdown

    private var cardTypeBreakdown: some View {
        let types: [(FlashcardType, String)] = [
            (.consonant, "Consonants"),
            (.vowel, "Vowels"),
            (.toneMark, "Tone Marks"),
            (.toneRule, "Tone Rules")
        ]

        return ForEach(types, id: \.0) { type, name in
            let cardsOfType = filteredCards.filter { $0.type == type }
            let dueCount = learningModel.dueCardCount(in: cardsOfType)
            let masteredCount = learningModel.masteredCardCount(in: cardsOfType)
            let totalCount = cardsOfType.count

            if totalCount > 0 {
                HStack {
                    Text(name)
                    Spacer()
                    Text("\(masteredCount)/\(totalCount) mastered")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if dueCount > 0 {
                        Text("\(dueCount) due")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func calculateStageCounts() -> [SRSStage: Int] {
        var counts: [SRSStage: Int] = [:]
        for stage in SRSStage.allCases {
            counts[stage] = 0
        }
        for card in filteredCards {
            let stage = learningModel.srsStage(for: card)
            counts[stage, default: 0] += 1
        }
        return counts
    }
}

// MARK: - Stat Box Component

private struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    SRSStatsView(
        learningModel: LearningModel(),
        filteredCards: []
    )
}

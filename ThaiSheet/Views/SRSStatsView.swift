//
//  SRSStatsView.swift
//  ThaiSheet
//

import SwiftUI

struct SRSStatsView: View {
    let learningModel: LearningModel
    let filteredCards: [FlashcardItem]
    let allCards: [FlashcardItem]
    let hasActiveFilters: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetConfirmation = false
    @State private var showAllCards = false

    /// The cards to display stats for (filtered or all based on toggle)
    private var displayedCards: [FlashcardItem] {
        showAllCards ? allCards : filteredCards
    }

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
            .navigationTitle(showAllCards ? "Progress (All)" : "Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if hasActiveFilters {
                        Button {
                            showAllCards.toggle()
                        } label: {
                            Image(systemName: showAllCards ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        }
                    }
                }
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

    /// Grouped stage for display (combines stages with same display name)
    private enum StageGroup: String, CaseIterable {
        case new = "New"
        case learning = "Learning"
        case apprentice = "Apprentice"
        case familiar = "Familiar"
        case confident = "Confident"
        case mastered = "Mastered"

        var color: Color {
            switch self {
            case .new: return .gray
            case .learning: return .blue
            case .apprentice: return .pink
            case .familiar: return .purple
            case .confident: return .indigo
            case .mastered: return .yellow
            }
        }

        var stages: [SRSStage] {
            switch self {
            case .new: return [.new]
            case .learning: return [.learning1, .learning2]
            case .apprentice: return [.apprentice1, .apprentice2]
            case .familiar: return [.familiar1, .familiar2]
            case .confident: return [.confident]
            case .mastered: return [.mastered]
            }
        }
    }

    private var stageDistributionChart: some View {
        let stageCounts = calculateStageCounts()
        let groupedCounts = calculateGroupedCounts(from: stageCounts)
        let maxCount = groupedCounts.values.max() ?? 1

        return VStack(alignment: .leading, spacing: 8) {
            ForEach(StageGroup.allCases, id: \.rawValue) { group in
                let count = groupedCounts[group] ?? 0
                HStack(spacing: 8) {
                    Text(group.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)

                    GeometryReader { geometry in
                        let barWidth = maxCount > 0
                            ? geometry.size.width * CGFloat(count) / CGFloat(maxCount)
                            : 0

                        RoundedRectangle(cornerRadius: 3)
                            .fill(group.color)
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

    private func calculateGroupedCounts(from stageCounts: [SRSStage: Int]) -> [StageGroup: Int] {
        var grouped: [StageGroup: Int] = [:]
        for group in StageGroup.allCases {
            grouped[group] = group.stages.reduce(0) { $0 + (stageCounts[$1] ?? 0) }
        }
        return grouped
    }

    // MARK: - Summary Stats

    private var summaryStats: some View {
        let dueCount = learningModel.dueCardCount(in: displayedCards)
        let familiarCount = learningModel.familiarCardCount(in: displayedCards)
        let masteredCount = learningModel.masteredCardCount(in: displayedCards)
        let totalCards = displayedCards.count
        let familiarPercent = totalCards > 0 ? Int(Double(familiarCount) / Double(totalCards) * 100) : 0
        let masteredPercent = totalCards > 0 ? Int(Double(masteredCount) / Double(totalCards) * 100) : 0
        let successRate = learningModel.overallSuccessRate

        return VStack(spacing: 12) {
            HStack {
                StatBox(title: "Due Now", value: "\(dueCount)", color: .orange)
                StatBox(title: "Total Cards", value: "\(totalCards)", color: .blue)
            }
            HStack {
                StatBox(title: "Familiar", value: "\(familiarCount) (\(familiarPercent)%)", color: .purple)
                StatBox(title: "Mastered", value: "\(masteredCount) (\(masteredPercent)%)", color: .yellow)
            }
            HStack {
                StatBox(
                    title: "Success Rate",
                    value: successRate.map { "\(Int($0 * 100))%" } ?? "—",
                    color: .green
                )
                StatBox(title: "Cards Reviewed", value: "\(learningModel.reviewedCardCount)", color: .indigo)
            }
        }
    }

    // MARK: - Card Type Breakdown

    private var cardTypeBreakdown: some View {
        return ForEach(FlashcardType.allCases, id: \.self) { type in
            let name = type.label + "s"
            let cardsOfType = displayedCards.filter { $0.type == type }
            let dueCount = learningModel.dueCardCount(in: cardsOfType)
            let familiarCount = learningModel.familiarCardCount(in: cardsOfType)
            let masteredCount = learningModel.masteredCardCount(in: cardsOfType)
            let totalCount = cardsOfType.count

            if totalCount > 0 {
                HStack {
                    Text(name)
                    Spacer()
                    Text("\(familiarCount)/\(totalCount) familiar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(masteredCount) mastered")
                        .font(.caption)
                        .foregroundColor(.yellow)
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
        for card in displayedCards {
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
        filteredCards: [],
        allCards: [],
        hasActiveFilters: true
    )
}

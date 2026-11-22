//
//  RoundSummaryView.swift
//  ThaiSheet
//

import SwiftUI

/// The end of a Shuffled pass or follow-up round: where every card ended up
/// (correct + missed + skipped = the deck), the cards left to retry, and the
/// next steps.
struct RoundSummaryView: View {
    let summary: ShuffledStrategy.Summary
    let onRetry: () -> Void
    let onAnswerSkipped: () -> Void
    let onPracticeMissed: () -> Void
    let onNewRound: () -> Void

    private enum Action {
        case retry, answerSkipped, practiceMissed, newRound
    }

    /// Available actions in order; the first is the prominent one. Practicing
    /// missed cards again is optional and never takes the prominent slot.
    private var actions: [Action] {
        var available: [Action] = []
        if summary.leftToRetry > 0 { available.append(.retry) }
        if summary.skipped > 0 { available.append(.answerSkipped) }
        if summary.canPracticeMissed { available.append(.practiceMissed) }
        available.append(.newRound)
        let primary = available.first { $0 != .practiceMissed } ?? .newRound
        return [primary] + available.filter { $0 != primary }
    }

    var body: some View {
        ContentUnavailableView {
            Label("Pass complete", systemImage: "checkmark.circle")
        } description: {
            VStack(spacing: 16) {
                HStack(spacing: 24) {
                    stat("Correct", summary.correct)
                    stat("Missed", summary.missed)
                    stat("Skipped", summary.skipped)
                }
                if summary.missed > 0 {
                    if summary.leftToRetry > 0 {
                        Text("Left to retry: \(summary.leftToRetry)")
                    } else {
                        Text("All retried")
                    }
                }
            }
        } actions: {
            ForEach(Array(actions.enumerated()), id: \.offset) { offset, action in
                if offset == 0 {
                    button(action).buttonStyle(.borderedProminent)
                } else {
                    button(action)
                }
            }
        }
    }

    @ViewBuilder
    private func button(_ action: Action) -> some View {
        switch action {
        case .retry:
            Button("Retry \(summary.leftToRetry)", action: onRetry)
        case .answerSkipped:
            Button("Answer skipped cards", action: onAnswerSkipped)
        case .practiceMissed:
            Button("Practice missed again", action: onPracticeMissed)
        case .newRound:
            Button("New round", action: onNewRound)
        }
    }

    private func stat(_ title: LocalizedStringKey, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(value, format: .number)
                .font(.title2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Misses left, skipped cards") {
    RoundSummaryView(
        summary: .init(correct: 7, missed: 3, skipped: 2, leftToRetry: 3),
        onRetry: {}, onAnswerSkipped: {}, onPracticeMissed: {}, onNewRound: {}
    )
}

#Preview("All retried") {
    RoundSummaryView(
        summary: .init(correct: 9, missed: 3, skipped: 0, leftToRetry: 0),
        onRetry: {}, onAnswerSkipped: {}, onPracticeMissed: {}, onNewRound: {}
    )
}

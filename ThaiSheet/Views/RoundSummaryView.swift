//
//  RoundSummaryView.swift
//  ThaiSheet
//

import SwiftUI

/// The end of a Shuffled pass or retry round: the pass totals, the cards left
/// to retry, and the next step.
struct RoundSummaryView: View {
    let summary: ShuffledStrategy.Summary
    let onRetry: () -> Void
    let onNewRound: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Pass complete", systemImage: "checkmark.circle")
        } description: {
            VStack(spacing: 16) {
                HStack(spacing: 24) {
                    stat("Answered", summary.answered)
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
            if summary.leftToRetry > 0 {
                Button("Retry \(summary.leftToRetry)", action: onRetry)
                    .buttonStyle(.borderedProminent)
                Button("New round", action: onNewRound)
            } else {
                Button("New round", action: onNewRound)
                    .buttonStyle(.borderedProminent)
            }
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

#Preview("Misses left") {
    RoundSummaryView(
        summary: .init(answered: 10, missed: 3, skipped: 2, leftToRetry: 3),
        onRetry: {},
        onNewRound: {}
    )
}

#Preview("All retried") {
    RoundSummaryView(
        summary: .init(answered: 12, missed: 3, skipped: 0, leftToRetry: 0),
        onRetry: {},
        onNewRound: {}
    )
}

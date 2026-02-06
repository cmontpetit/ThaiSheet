//
//  ToneRuleFlashcardView.swift
//  ThaiSheet
//

import SwiftUI

struct ToneRuleFlashcardView: View {
    let card: ToneRuleCard
    var onViewInReference: ((String) -> Void)?
    var onComplete: ((Bool) -> Void)?
    let onNext: () -> Void
    let onPrevious: () -> Void

    @Environment(\.audioPlayer) private var audioPlayer
    @State private var cardState = ToneRuleCardState()

    // Selection options (value = data identifier matching JSON, label = localized display)
    private struct Option: Identifiable {
        let value: String
        var label: String { String(localized: String.LocalizationValue(value)) }
        var id: String { value }
    }

    private let consonantClassOptions: [Option] = [
        Option(value: "Low"), Option(value: "Mid"), Option(value: "High"),
    ]
    private let vowelDurationOptions: [Option] = [
        Option(value: "Short"), Option(value: "Long"), Option(value: "Any"),
    ]
    private let endOptions: [Option] = [
        Option(value: "Live"), Option(value: "Dead"),
    ]
    private let toneOptions: [Option] = [
        Option(value: "Low"), Option(value: "Mid"), Option(value: "High"),
        Option(value: "Falling"), Option(value: "Rising"),
    ]

    /// Localize a data identifier for display
    private func localized(_ value: String) -> String {
        String(localized: String.LocalizationValue(value))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Sample word display with status indicator
                sampleWordCardView

                // Summary section
                summarySection

                // Selection area
                selectionArea
            }
            .padding()
        }
        .onChange(of: card.id) { _, _ in
            // Reset state when card changes
            cardState = ToneRuleCardState()
        }
    }

    // MARK: - Sample Word Card View

    private var sampleWordCardView: some View {
        FlashcardResultCard(
            showResult: cardState.step == .completed,
            hasError: cardState.hasError(for: card)
        ) {
            VStack(spacing: 12) {
                // Main character with swipe gestures for navigation and reveal
                NavigableTapArea(
                    onPrevious: handlePrevious,
                    onNext: handleNext,
                    onReveal: cardState.step != .completed ? { completeCardEarly() } : nil
                ) {
                    // Display the sample word with focus highlighting
                    sampleWordText
                }
                .frame(height: 160)

                // Action buttons
                HStack(spacing: 20) {
                    // View in Reference button
                    Button {
                        onViewInReference?(card.rule.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "book")
                            Text("Reference")
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                    }

                    // Speaker button (only when completed)
                    if cardState.step == .completed {
                        let hasSound = audioPlayer.hasSound(.toneRule, key: card.sample.full)
                        Button {
                            audioPlayer.play(.toneRule, key: card.sample.full)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: hasSound ? "speaker.wave.2.fill" : "speaker.slash")
                                Text("Play")
                            }
                            .font(.subheadline)
                            .foregroundColor(hasSound ? .accentColor : .secondary)
                        }
                        .disabled(!hasSound)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .cornerRadius(16)
    }

    @ViewBuilder
    private var sampleWordText: some View {
        let full = card.sample.full
        let focus = card.sample.focus

        if full == focus {
            // Simple case: entire word is the focus
            Text(full)
                .font(.system(size: 72))
                .minimumScaleFactor(0.5)
        } else if let range = full.range(of: focus) {
            // Highlight only the focus part
            let before = String(full[..<range.lowerBound])
            let focusPart = String(full[range])
            let after = String(full[range.upperBound...])

            HStack(spacing: 0) {
                if !before.isEmpty {
                    Text(before)
                        .font(.system(size: 72))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                Text(focusPart)
                    .font(.system(size: 72))
                    .foregroundColor(.primary)
                if !after.isEmpty {
                    Text(after)
                        .font(.system(size: 72))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .minimumScaleFactor(0.5)
        } else {
            // Fallback: just show the full word
            Text(full)
                .font(.system(size: 72))
                .minimumScaleFactor(0.5)
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlashcardSummaryHeader(
                showReveal: cardState.step != .completed,
                onReveal: { completeCardEarly() }
            )

            VStack(spacing: 6) {
                FlashcardSummaryRow(
                    label: "Class",
                    selectedValue: cardState.selectedConsonantClass.map { localized($0) },
                    correctValue: localized(card.rule.initialConsonant),
                    showResult: cardState.step == .completed,
                    labelWidth: 50
                )
                FlashcardSummaryRow(
                    label: "Vowel",
                    selectedValue: cardState.selectedVowelDuration.map { localized($0) },
                    correctValue: localized(card.rule.vowelDuration),
                    showResult: cardState.step == .completed,
                    labelWidth: 50
                )
                FlashcardSummaryRow(
                    label: "End",
                    selectedValue: cardState.selectedEnd.map { localized($0) },
                    correctValue: localized(normalizedEnd(card.rule.end)),
                    showResult: cardState.step == .completed,
                    labelWidth: 50
                )
                FlashcardSummaryRow(
                    label: "Tone",
                    selectedValue: cardState.selectedTone.map { localized($0) },
                    correctValue: localized(card.correctTone),
                    showResult: cardState.step == .completed,
                    labelWidth: 50
                )

                // Show note when completed
                if cardState.step == .completed, let note = card.sample.note {
                    Divider()
                        .padding(.vertical, 4)
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // Normalize "Dead/None" to "Dead" for comparison
    private func normalizedEnd(_ end: String) -> String {
        end == "Dead/None" ? "Dead" : end
    }

    // MARK: - Selection Area

    @ViewBuilder
    private var selectionArea: some View {
        switch cardState.step {
        case .selectConsonantClass:
            selectionView(
                title: "Select the consonant class",
                options: consonantClassOptions
            ) { selection in
                cardState.selectedConsonantClass = selection
                cardState.step = .selectVowelDuration
            }
        case .selectVowelDuration:
            selectionView(
                title: "Select the vowel duration",
                options: vowelDurationOptions
            ) { selection in
                cardState.selectedVowelDuration = selection
                cardState.step = .selectEnd
            }
        case .selectEnd:
            selectionView(
                title: "Select the syllable ending",
                options: endOptions
            ) { selection in
                cardState.selectedEnd = selection
                cardState.step = .selectTone
            }
        case .selectTone:
            selectionView(
                title: "Select the tone",
                options: toneOptions
            ) { selection in
                cardState.selectedTone = selection
                completeCard()
            }
        case .completed:
            nextCardButton
        }
    }

    // MARK: - Generic Selection View

    private func selectionView(title: LocalizedStringKey, options: [Option], onSelect: @escaping (String) -> Void) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)

            // Flexible layout based on number of options
            if options.count <= 3 {
                HStack(spacing: 8) {
                    ForEach(options) { option in
                        selectionButton(option, onSelect: onSelect)
                    }
                }
            } else {
                // Two rows for more options
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(Array(options.prefix(3))) { option in
                            selectionButton(option, onSelect: onSelect)
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(Array(options.dropFirst(3))) { option in
                            selectionButton(option, onSelect: onSelect)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func selectionButton(_ option: Option, onSelect: @escaping (String) -> Void) -> some View {
        FlashcardSelectionButton(label: option.label) {
            onSelect(option.value)
        }
    }

    // MARK: - Card Completion

    private func completeCard() {
        cardState.step = .completed
        // Record result: correct if no errors were made
        let wasCorrect = !cardState.hasError(for: card)
        onComplete?(wasCorrect)
        if audioPlayer.hasSound(.toneRule, key: card.sample.full) {
            audioPlayer.play(.toneRule, key: card.sample.full)
        }
    }

    private func completeCardEarly() {
        cardState.step = .completed
        // Revealed early = not answered correctly
        onComplete?(false)
        if audioPlayer.hasSound(.toneRule, key: card.sample.full) {
            audioPlayer.play(.toneRule, key: card.sample.full)
        }
    }

    // MARK: - Next Card Button

    private var nextCardButton: some View {
        FlashcardNextButton {
            handleNext()
        }
    }

    // MARK: - Navigation

    private func handleNext() {
        cardState = ToneRuleCardState()
        onNext()
    }

    private func handlePrevious() {
        cardState = ToneRuleCardState()
        onPrevious()
    }
}

// MARK: - Tone Rule Card State

struct ToneRuleCardState {
    enum Step {
        case selectConsonantClass
        case selectVowelDuration
        case selectEnd
        case selectTone
        case completed
    }

    var step: Step = .selectConsonantClass
    var selectedConsonantClass: String? = nil
    var selectedVowelDuration: String? = nil
    var selectedEnd: String? = nil
    var selectedTone: String? = nil
}

extension ToneRuleCardState {
    func hasError(for card: ToneRuleCard) -> Bool {
        let normalizedCorrectEnd = card.rule.end == "Dead/None" ? "Dead" : card.rule.end

        if let selected = selectedConsonantClass, selected != card.rule.initialConsonant {
            return true
        }
        if let selected = selectedVowelDuration, selected != card.rule.vowelDuration {
            return true
        }
        if let selected = selectedEnd, selected != normalizedCorrectEnd {
            return true
        }
        if let selected = selectedTone, selected != card.correctTone {
            return true
        }
        return false
    }
}

#Preview {
    let cards = ToneRuleCard.allCards(from: ToneRule.loadAll())
    return NavigationStack {
        if let first = cards.first {
            ToneRuleFlashcardView(
                card: first,
                onViewInReference: { _ in },
                onNext: {},
                onPrevious: {}
            )
        } else {
            Text("No tone rule data")
        }
    }
}

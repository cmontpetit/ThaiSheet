//
//  ToneRuleFlashcardView.swift
//  ThaiSheet
//

import SwiftUI

// Represents a single tone rule flashcard (one sample from a rule)
struct ToneRuleCard: Identifiable {
    let rule: ToneRule
    let sample: ToneSample
    let correctTone: String

    var id: String { "\(rule.id)-\(sample.full)" }

    static func allCards(from rules: [ToneRule]) -> [ToneRuleCard] {
        var cards: [ToneRuleCard] = []
        for rule in rules {
            guard let samples = rule.samples else { continue }
            for sample in samples {
                cards.append(ToneRuleCard(
                    rule: rule,
                    sample: sample,
                    correctTone: rule.tone
                ))
            }
        }
        return cards.shuffled()
    }
}

struct ToneRuleFlashcardView: View {
    let card: ToneRuleCard
    var onViewInReference: ((String) -> Void)?
    var onComplete: ((Bool) -> Void)?
    let onNext: () -> Void
    let onPrevious: () -> Void

    @State private var cardState = ToneRuleCardState()

    // Selection options
    private let consonantClassOptions = ["Low", "Mid", "High"]
    private let vowelDurationOptions = ["Short", "Long", "Any"]
    private let endOptions = ["Live", "Dead"]
    private let toneOptions = ["Low", "Mid", "High", "Falling", "Rising"]

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
                        let hasSound = AudioPlayer.shared.hasToneRuleSound(for: card.sample.full)
                        Button {
                            AudioPlayer.shared.playToneRuleSound(for: card.sample.full)
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
                    selectedValue: cardState.selectedConsonantClass,
                    correctValue: card.rule.initialConsonant,
                    showResult: cardState.step == .completed,
                    labelWidth: 50
                )
                FlashcardSummaryRow(
                    label: "Vowel",
                    selectedValue: cardState.selectedVowelDuration,
                    correctValue: card.rule.vowelDuration,
                    showResult: cardState.step == .completed,
                    labelWidth: 50
                )
                FlashcardSummaryRow(
                    label: "End",
                    selectedValue: cardState.selectedEnd,
                    correctValue: normalizedEnd(card.rule.end),
                    showResult: cardState.step == .completed,
                    labelWidth: 50
                )
                FlashcardSummaryRow(
                    label: "Tone",
                    selectedValue: cardState.selectedTone,
                    correctValue: card.correctTone,
                    showResult: cardState.step == .completed,
                    labelWidth: 50
                )
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

    private func selectionView(title: String, options: [String], onSelect: @escaping (String) -> Void) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)

            // Flexible layout based on number of options
            if options.count <= 3 {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        selectionButton(option, onSelect: onSelect)
                    }
                }
            } else {
                // Two rows for more options
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(options.prefix(3), id: \.self) { option in
                            selectionButton(option, onSelect: onSelect)
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(options.dropFirst(3), id: \.self) { option in
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

    private func selectionButton(_ option: String, onSelect: @escaping (String) -> Void) -> some View {
        FlashcardSelectionButton(label: option) {
            onSelect(option)
        }
    }

    // MARK: - Card Completion

    private func completeCard() {
        cardState.step = .completed
        // Record result: correct if no errors were made
        let wasCorrect = !cardState.hasError(for: card)
        onComplete?(wasCorrect)
        if AudioPlayer.shared.hasToneRuleSound(for: card.sample.full) {
            AudioPlayer.shared.playToneRuleSound(for: card.sample.full)
        }
    }

    private func completeCardEarly() {
        cardState.step = .completed
        // Revealed early = not answered correctly
        onComplete?(false)
        if AudioPlayer.shared.hasToneRuleSound(for: card.sample.full) {
            AudioPlayer.shared.playToneRuleSound(for: card.sample.full)
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
    NavigationStack {
        ToneRuleFlashcardView(
            card: ToneRuleCard.allCards(from: ToneRule.loadAll()).first!,
            onViewInReference: { _ in },
            onNext: {},
            onPrevious: {}
        )
    }
}

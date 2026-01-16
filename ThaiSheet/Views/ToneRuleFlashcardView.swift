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
    let cards: [ToneRuleCard]
    @Binding var currentIndex: Int
    @Binding var startingRuleId: String?
    var onViewInReference: (() -> Void)?
    var onNextCard: (() -> Void)?

    @State private var cardState = ToneRuleCardState()

    // All possible tones for selection
    private let toneOptions = ["Low", "Mid", "High", "Falling", "Rising"]

    var currentCard: ToneRuleCard? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var body: some View {
        if let card = currentCard {
            ScrollView {
                VStack(spacing: 20) {
                    // Sample word display with status indicator
                    sampleWordCardView(card: card)

                    // Summary section
                    summarySection(card: card)

                    // Selection area
                    selectionArea(card: card)

                    // Progress indicator
                    progressIndicator
                }
                .padding()
            }
            .onAppear {
                if let startId = startingRuleId,
                   let index = cards.firstIndex(where: { $0.rule.id == startId }) {
                    currentIndex = index
                    startingRuleId = nil
                }
            }
            .onChange(of: startingRuleId) { _, newValue in
                if let startId = newValue,
                   let index = cards.firstIndex(where: { $0.rule.id == startId }) {
                    currentIndex = index
                    cardState = ToneRuleCardState()
                    startingRuleId = nil
                }
            }
        } else {
            ContentUnavailableView(
                "No Tone Rules",
                systemImage: "character.book.closed",
                description: Text("No tone rules available")
            )
        }
    }

    // MARK: - Sample Word Card View

    private func sampleWordCardView(card: ToneRuleCard) -> some View {
        VStack(spacing: 12) {
            ZStack {
                // Status ring
                if cardState.step == .completed {
                    Circle()
                        .stroke(cardState.hasError(for: card) ? Color.red : Color.green, lineWidth: 4)
                        .frame(width: 160, height: 160)
                }

                // Display the sample word with focus highlighting
                sampleWordText(card: card)
            }

            // Rule description
            Text(ruleDescription(card: card))
                .font(.caption)
                .foregroundColor(.secondary)

            // Action buttons
            HStack(spacing: 20) {
                // View in Reference button
                Button {
                    onViewInReference?()
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
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    @ViewBuilder
    private func sampleWordText(card: ToneRuleCard) -> some View {
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

    private func ruleDescription(card: ToneRuleCard) -> String {
        "\(card.rule.initialConsonant) + \(card.rule.vowelDuration) + \(card.rule.end)"
    }

    // MARK: - Summary Section

    private func summarySection(card: ToneRuleCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 6) {
                summaryRow(
                    label: "Tone",
                    selectedValue: cardState.selectedTone,
                    correctValue: card.correctTone,
                    isCorrect: cardState.selectedTone == card.correctTone,
                    wasSelected: cardState.selectedTone != nil,
                    showResult: cardState.step == .completed
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private func summaryRow(label: String, selectedValue: String?, correctValue: String, isCorrect: Bool, wasSelected: Bool, showResult: Bool) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            if showResult {
                if wasSelected {
                    if isCorrect {
                        Text(selectedValue ?? correctValue)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.green)
                    } else {
                        Text(correctValue)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        Text(selectedValue ?? "")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.red.opacity(0.5))
                            .strikethrough(color: .red.opacity(0.5))
                    }
                } else {
                    Text(correctValue)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                }
            } else if let selected = selectedValue {
                Text(selected)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Selection Area

    @ViewBuilder
    private func selectionArea(card: ToneRuleCard) -> some View {
        switch cardState.step {
        case .selectTone:
            toneSelectionView(card: card)
        case .completed:
            nextCardButton
        }
    }

    // MARK: - Tone Selection

    private func toneSelectionView(card: ToneRuleCard) -> some View {
        VStack(spacing: 16) {
            Text("Select the tone")
                .font(.headline)

            // 5 tone buttons in a row
            HStack(spacing: 8) {
                ForEach(toneOptions, id: \.self) { tone in
                    Button {
                        cardState.selectedTone = tone
                        completeCard(card: card)
                    } label: {
                        Text(tone)
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Card Completion

    private func completeCard(card: ToneRuleCard) {
        cardState.step = .completed
        if AudioPlayer.shared.hasToneRuleSound(for: card.sample.full) {
            AudioPlayer.shared.playToneRuleSound(for: card.sample.full)
        }
    }

    // MARK: - Next Card Button

    private var nextCardButton: some View {
        Button {
            goToNextCard()
        } label: {
            HStack {
                Text("Next Card")
                Image(systemName: "arrow.right")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        Text("\(currentIndex + 1) / \(cards.count)")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 8)
    }

    // MARK: - Actions

    private func goToNextCard() {
        cardState = ToneRuleCardState()
        currentIndex = (currentIndex + 1) % cards.count
        onNextCard?()
    }
}

// MARK: - Tone Rule Card State

struct ToneRuleCardState {
    enum Step {
        case selectTone
        case completed
    }

    var step: Step = .selectTone
    var selectedTone: String? = nil
}

extension ToneRuleCardState {
    func hasError(for card: ToneRuleCard) -> Bool {
        if let selected = selectedTone, selected != card.correctTone {
            return true
        }
        return false
    }
}

#Preview {
    NavigationStack {
        ToneRuleFlashcardView(
            cards: ToneRuleCard.allCards(from: ToneRule.loadAll()),
            currentIndex: .constant(0),
            startingRuleId: .constant(nil),
            onViewInReference: { },
            onNextCard: { }
        )
    }
}

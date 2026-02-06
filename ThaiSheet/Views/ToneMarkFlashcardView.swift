//
//  ToneMarkFlashcardView.swift
//  ThaiSheet
//

import SwiftUI

struct ToneMarkFlashcardView: View {
    let card: ToneMarkCard
    var onViewInReference: ((String) -> Void)?
    var onComplete: ((Bool) -> Void)?
    let onNext: () -> Void
    let onPrevious: () -> Void

    @Environment(\.audioPlayer) private var audioPlayer
    @State private var cardState = ToneMarkCardState()

    // All possible tones for selection (value = data identifier, label = localized display)
    private struct ToneOption: Identifiable {
        let value: String
        var label: String { String(localized: String.LocalizationValue(value)) }
        var id: String { value }
    }

    private let toneOptions: [ToneOption] = [
        ToneOption(value: "Low"), ToneOption(value: "Mid"), ToneOption(value: "High"),
        ToneOption(value: "Falling"), ToneOption(value: "Rising"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Tone mark display with status indicator
                toneMarkCardView

                // Summary section
                summarySection

                // Selection area
                selectionArea
            }
            .padding()
        }
        .onChange(of: card.id) { _, _ in
            // Reset state when card changes
            cardState = ToneMarkCardState()
        }
    }

    // MARK: - Tone Mark Card View

    private var toneMarkCardView: some View {
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
                    Text(card.display)
                        .font(.system(size: 100))
                        .minimumScaleFactor(0.5)
                }
                .frame(height: 160)

                // Action buttons
                HStack(spacing: 20) {
                    // View in Reference button
                    Button {
                        onViewInReference?(card.display)
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
                        let hasSound = audioPlayer.hasSound(.toneMark, key: card.display)
                        Button {
                            audioPlayer.play(.toneMark, key: card.display)
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
                    selectedValue: cardState.selectedClass?.label,
                    correctValue: card.consonantClass.label,
                    showResult: cardState.step == .completed
                )
                FlashcardSummaryRow(
                    label: "Tone",
                    selectedValue: cardState.selectedTone.map { String(localized: String.LocalizationValue($0)) },
                    correctValue: String(localized: String.LocalizationValue(card.correctTone)),
                    showResult: cardState.step == .completed
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // MARK: - Selection Area

    @ViewBuilder
    private var selectionArea: some View {
        switch cardState.step {
        case .selectClass:
            classSelectionView
        case .selectTone:
            toneSelectionView
        case .completed:
            nextCardButton
        }
    }

    // MARK: - Class Selection

    private var classSelectionView: some View {
        VStack(spacing: 16) {
            Text("Select the consonant class")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(ToneMarkCard.ConsonantClassType.allCases, id: \.self) { classType in
                    Button {
                        cardState.selectedClass = classType
                        cardState.step = .selectTone
                    } label: {
                        Text(classType.label)
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

    // MARK: - Tone Selection

    private var toneSelectionView: some View {
        VStack(spacing: 16) {
            Text("Select the tone")
                .font(.headline)

            // 5 tone buttons in a row
            HStack(spacing: 8) {
                ForEach(toneOptions) { tone in
                    Button {
                        cardState.selectedTone = tone.value
                        completeCard()
                    } label: {
                        Text(tone.label)
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

    private func completeCard() {
        cardState.step = .completed
        // Record result: correct if no errors were made
        let wasCorrect = !cardState.hasError(for: card)
        onComplete?(wasCorrect)
        if audioPlayer.hasSound(.toneMark, key: card.display) {
            audioPlayer.play(.toneMark, key: card.display)
        }
    }

    private func completeCardEarly() {
        cardState.step = .completed
        // Revealed early = not answered correctly
        onComplete?(false)
        if audioPlayer.hasSound(.toneMark, key: card.display) {
            audioPlayer.play(.toneMark, key: card.display)
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
        cardState = ToneMarkCardState()
        onNext()
    }

    private func handlePrevious() {
        cardState = ToneMarkCardState()
        onPrevious()
    }
}

// MARK: - Tone Mark Card State

struct ToneMarkCardState {
    enum Step {
        case selectClass
        case selectTone
        case completed
    }

    var step: Step = .selectClass
    var selectedClass: ToneMarkCard.ConsonantClassType? = nil
    var selectedTone: String? = nil
}

extension ToneMarkCardState {
    func hasError(for card: ToneMarkCard) -> Bool {
        if let selected = selectedClass, selected != card.consonantClass {
            return true
        }
        if let selected = selectedTone, selected != card.correctTone {
            return true
        }
        return false
    }
}

#Preview {
    let cards = ToneMarkCard.allCards(from: ToneMark.loadAll())
    return NavigationStack {
        if let first = cards.first {
            ToneMarkFlashcardView(
                card: first,
                onViewInReference: { _ in },
                onNext: {},
                onPrevious: {}
            )
        } else {
            Text("No tone mark data")
        }
    }
}

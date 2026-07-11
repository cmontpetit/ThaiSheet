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
    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 100

    // All possible tones for selection
    private let toneOptions: [LocalizedOption] = [
        LocalizedOption(value: "Low"), LocalizedOption(value: "Mid"), LocalizedOption(value: "High"),
        LocalizedOption(value: "Falling"), LocalizedOption(value: "Rising"),
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
            .contentColumn()
        }
        .onChange(of: card.id) { _, _ in
            // Reset state when card changes
            cardState = ToneMarkCardState()
        }
    }

    // MARK: - Tone Mark Card View

    private var toneMarkCardView: some View {
        FlashcardFace(
            showResult: cardState.step == .completed,
            hasError: cardState.hasError(for: card),
            soundType: .toneMark,
            soundKey: card.display,
            onViewInReference: { onViewInReference?(card.display) },
            onPrevious: handlePrevious,
            onNext: handleNext
        ) {
            Text(card.display)
                .font(.system(size: glyphSize))
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

            FlashcardSummaryGrid {
                FlashcardSummaryRow(
                    label: "Class",
                    selectedValue: cardState.selectedClass?.label,
                    correctValue: card.consonantClass.label,
                    showResult: cardState.step == .completed
                )
                FlashcardSummaryRow(
                    label: "Tone",
                    selectedValue: cardState.selectedTone.map { ThaiColors.toneDisplay($0) },
                    correctValue: ThaiColors.toneDisplay(card.correctTone),
                    showResult: cardState.step == .completed
                )
            }
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
        FlashcardStepSection(title: "Select the consonant class") {
            HStack(spacing: 12) {
                ForEach(ToneMarkCard.ConsonantClassType.allCases, id: \.self) { classType in
                    FlashcardSelectionButton(label: classType.label, background: classType.buttonBackground) {
                        cardState.selectedClass = classType
                        cardState.step = .selectTone
                    }
                }
            }
        }
    }

    // MARK: - Tone Selection

    private var toneSelectionView: some View {
        FlashcardStepSection(title: "Select the tone") {
            // 5 tone buttons in a row, shown as tone diacritics (à a á â ǎ)
            // matching the transcription convention
            HStack(spacing: 8) {
                ForEach(toneOptions) { tone in
                    FlashcardSelectionButton(
                        label: ThaiColors.toneDiacritic(tone.value),
                        background: ThaiColors.toneButtonBackground(tone.value),
                        font: .title2,
                        accessibilityLabel: tone.label
                    ) {
                        cardState.selectedTone = tone.value
                        completeCard()
                    }
                }
            }
        }
    }

    // MARK: - Card Completion

    private func completeCard(revealed: Bool = false) {
        cardState.step = .completed
        // Revealed early counts as incorrect; otherwise correct if no errors were made
        onComplete?(revealed ? false : !cardState.hasError(for: card))
        if audioPlayer.hasSound(.toneMark, key: card.display) {
            audioPlayer.play(.toneMark, key: card.display)
        }
    }

    private func completeCardEarly() {
        completeCard(revealed: true)
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

private extension ToneMarkCard.ConsonantClassType {
    /// Class colors matching the consonant reference
    var buttonBackground: AnyShapeStyle {
        switch self {
        case .low: return AnyShapeStyle(ConsonantClass.low.color)
        case .mid: return AnyShapeStyle(ConsonantClass.mid.color)
        case .high: return AnyShapeStyle(ConsonantClass.high.color)
        }
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

//
//  VowelFlashcardView.swift
//  ThaiSheet
//

import SwiftUI

struct VowelFlashcardView: View {
    let card: VowelCard
    let allVowels: [Vowel]  // For generating quiz options
    var onViewInReference: ((String) -> Void)?
    var onComplete: ((Bool) -> Void)?
    let onNext: () -> Void
    let onPrevious: () -> Void

    @Environment(\.audioPlayer) private var audioPlayer
    @State private var cardState = VowelCardState()

    // Generated options for sound selection
    @State private var soundOptions: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Vowel display with status indicator
                vowelCardView

                // Summary section
                summarySection

                // Selection area (changes based on current step)
                selectionArea
            }
            .padding()
        }
        .onAppear {
            generateOptions()
        }
        .onChange(of: card.id) { _, _ in
            // Reset state when card changes
            cardState = VowelCardState()
            generateOptions()
        }
    }

    // MARK: - Vowel Card View

    private var vowelCardView: some View {
        FlashcardFace(
            showResult: cardState.step == .completed,
            hasError: cardState.hasError(for: card),
            soundType: .vowel,
            soundKey: card.display,
            onViewInReference: { onViewInReference?(card.display) },
            onPrevious: handlePrevious,
            onNext: handleNext
        ) {
            Text(card.display.replacingOccurrences(of: "-", with: ""))
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
                    label: "Duration",
                    selectedValue: cardState.selectedDuration?.label,
                    correctValue: card.duration.label,
                    showResult: cardState.step == .completed,
                    labelWidth: 70,
                    alternativeCorrectValue: card.alternativeDuration?.label
                )
                FlashcardSummaryRow(
                    label: "Form",
                    selectedValue: cardState.selectedForm?.label,
                    correctValue: card.form.label,
                    showResult: cardState.step == .completed,
                    labelWidth: 70
                )
                FlashcardSummaryRow(
                    label: "Sound",
                    selectedValue: cardState.selectedSound,
                    correctValue: card.vowel.sound,
                    showResult: cardState.step == .completed,
                    labelWidth: 70
                )

                // Show note if available and card is completed
                if cardState.step == .completed,
                   let note = card.vowel.note(for: card.duration.rawValue, form: card.form.rawValue) {
                    Divider()
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

    // MARK: - Selection Area

    @ViewBuilder
    private var selectionArea: some View {
        switch cardState.step {
        case .selectDuration:
            durationSelectionView
        case .selectForm:
            formSelectionView
        case .selectSound:
            soundSelectionView
        case .completed:
            nextCardButton
        }
    }

    // MARK: - Duration Selection

    private var durationSelectionView: some View {
        FlashcardStepSection(title: "Select the duration") {
            HStack(spacing: 12) {
                ForEach(VowelCard.VowelDuration.allCases, id: \.self) { duration in
                    FlashcardSelectionButton(label: duration.label) {
                        cardState.selectedDuration = duration
                        cardState.step = .selectForm
                    }
                }
            }
        }
    }

    // MARK: - Form Selection

    private var formSelectionView: some View {
        FlashcardStepSection(title: "Select the form", onBack: {
            cardState.selectedDuration = nil
            cardState.step = .selectDuration
        }) {
            HStack(spacing: 12) {
                ForEach(VowelCard.VowelFormType.allCases, id: \.self) { form in
                    FlashcardSelectionButton(label: form.label) {
                        cardState.selectedForm = form
                        cardState.step = .selectSound
                    }
                }
            }
        }
    }

    // MARK: - Sound Selection

    private var soundSelectionView: some View {
        FlashcardStepSection(title: "Select the sound", onBack: {
            cardState.selectedForm = nil
            cardState.step = .selectForm
        }) {
            // 2 rows of 4 buttons
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(soundOptions, id: \.self) { sound in
                    FlashcardGridButton(label: sound) {
                        cardState.selectedSound = sound
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
        playVowelSound()
    }

    private func completeCardEarly() {
        completeCard(revealed: true)
    }

    private func playVowelSound() {
        if audioPlayer.hasSound(.vowel, key: card.display) {
            audioPlayer.play(.vowel, key: card.display)
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
        cardState = VowelCardState()
        onNext()
    }

    private func handlePrevious() {
        cardState = VowelCardState()
        onPrevious()
    }

    // MARK: - Option Generation

    private func generateOptions() {
        soundOptions = QuizOptions.pick(
            correct: card.vowel.sound,
            from: allVowels.map { $0.sound },
            wrongCount: 7
        )
    }
}

// MARK: - Vowel Card State

struct VowelCardState {
    enum Step {
        case selectDuration
        case selectForm
        case selectSound
        case completed
    }

    var step: Step = .selectDuration
    var selectedDuration: VowelCard.VowelDuration? = nil
    var selectedForm: VowelCard.VowelFormType? = nil
    var selectedSound: String? = nil
}

extension VowelCardState {
    func hasError(for card: VowelCard) -> Bool {
        // For duration: accept both if card accepts both durations
        if let selected = selectedDuration, selected != card.duration {
            if !card.acceptsBothDurations {
                return true
            }
        }
        if let selected = selectedForm, selected != card.form {
            return true
        }
        if let selected = selectedSound, selected != card.vowel.sound {
            return true
        }
        return false
    }
}

#Preview {
    let vowels = Vowel.loadAll()
    let cards = VowelCard.allCards(from: vowels)
    return NavigationStack {
        if let first = cards.first {
            VowelFlashcardView(
                card: first,
                allVowels: vowels,
                onViewInReference: { _ in },
                onNext: {},
                onPrevious: {}
            )
        } else {
            Text("No vowel data")
        }
    }
}

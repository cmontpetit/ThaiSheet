//
//  ConsonantFlashcardView.swift
//  ThaiSheet
//

import SwiftUI

struct ConsonantFlashcardView: View {
    let consonant: Consonant
    let allConsonants: [Consonant]  // For generating quiz options
    var onViewInReference: ((String) -> Void)?
    var onComplete: ((Bool) -> Void)?
    let onNext: () -> Void
    let onPrevious: () -> Void

    @Environment(\.audioPlayer) private var audioPlayer
    @State private var cardState = CardState()

    // Generated options for current card
    @State private var initialSoundOptions: [String] = []
    @State private var finalSoundOptions: [String] = []
    @State private var transcriptionOptions: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Consonant display with status indicator
                consonantCard

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
        .onChange(of: consonant.id) { _, _ in
            // Reset state when card changes
            cardState = CardState()
            generateOptions()
        }
    }

    // MARK: - Consonant Card

    private var consonantCard: some View {
        FlashcardFace(
            showResult: cardState.step == .completed,
            hasError: cardState.hasError(for: consonant),
            soundType: .consonant,
            soundKey: consonant.character,
            onViewInReference: { onViewInReference?(consonant.character) },
            onPrevious: handlePrevious,
            onNext: handleNext
        ) {
            Text(consonant.character)
                .font(.system(size: 100))
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
                    selectedValue: cardState.selectedClass?.displayName,
                    correctValue: consonant.consonantClass.displayName,
                    showResult: cardState.step == .completed
                )
                FlashcardSummaryRow(
                    label: "Initial",
                    selectedValue: cardState.selectedInitial,
                    correctValue: consonant.initialSound,
                    showResult: cardState.step == .completed
                )
                FlashcardSummaryRow(
                    label: "Final",
                    selectedValue: cardState.selectedFinal,
                    correctValue: consonant.finalSound,
                    showResult: cardState.step == .completed
                )
                FlashcardSummaryRow(
                    label: "Name",
                    selectedValue: cardState.selectedTranscription,
                    correctValue: consonant.transcription,
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
        case .selectInitial:
            initialSoundSelectionView
        case .selectFinal:
            finalSoundSelectionView
        case .selectTranscription:
            transcriptionSelectionView
        case .completed:
            nextCardButton
        }
    }

    // MARK: - Class Selection

    private var classSelectionView: some View {
        FlashcardStepSection(title: "Select the class") {
            HStack(spacing: 12) {
                ForEach(ConsonantClass.allCases, id: \.self) { classType in
                    Button {
                        cardState.selectedClass = classType
                        cardState.step = .selectInitial
                    } label: {
                        Text(classType.displayName)
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(classType.color)
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Initial Sound Selection

    private var initialSoundSelectionView: some View {
        FlashcardStepSection(title: "Select the initial sound", onBack: {
            cardState.selectedClass = nil
            cardState.step = .selectClass
        }) {
            // 2 rows of 4 buttons
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(initialSoundOptions, id: \.self) { sound in
                    FlashcardGridButton(label: sound) {
                        cardState.selectedInitial = sound
                        cardState.step = .selectFinal
                    }
                }
            }
        }
    }

    // MARK: - Final Sound Selection

    private var finalSoundSelectionView: some View {
        FlashcardStepSection(title: "Select the final sound", onBack: {
            cardState.selectedInitial = nil
            cardState.step = .selectInitial
        }) {
            // 1 row of 4 buttons
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(finalSoundOptions, id: \.self) { sound in
                    FlashcardGridButton(label: sound) {
                        cardState.selectedFinal = sound
                        cardState.step = .selectTranscription
                    }
                }
            }
        }
    }

    // MARK: - Transcription Selection

    private var transcriptionSelectionView: some View {
        FlashcardStepSection(title: "Select the transcription", onBack: {
            cardState.selectedFinal = nil
            cardState.step = .selectFinal
        }) {
            // 2 rows of 2 buttons
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(transcriptionOptions, id: \.self) { transcription in
                    FlashcardGridButton(label: transcription) {
                        cardState.selectedTranscription = transcription
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
        onComplete?(revealed ? false : !cardState.hasError(for: consonant))
        audioPlayer.play(.consonant, key: consonant.character)
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
        cardState = CardState()
        onNext()
    }

    private func handlePrevious() {
        cardState = CardState()
        onPrevious()
    }

    // MARK: - Option Generation

    private func generateOptions() {
        initialSoundOptions = QuizOptions.pick(
            correct: consonant.initialSound,
            from: allConsonants.map { $0.initialSound },
            wrongCount: 7
        )
        finalSoundOptions = QuizOptions.pick(
            correct: consonant.finalSound,
            from: allConsonants.map { $0.finalSound },
            wrongCount: 3
        )

        // Get transcriptions from other consonants (3 wrong + 1 correct = 4 total)
        // Prioritize confusers with the same prefix (e.g., "saaw" for both ส and ซ)
        transcriptionOptions = generateTranscriptionOptions()
    }

    /// Extracts the prefix from a transcription (first word, normalized without tone markers)
    private func transcriptionPrefix(_ transcription: String) -> String {
        // Get first word (before space)
        let firstWord = transcription.split(separator: " ").first.map(String.init) ?? transcription
        // Remove superscript tone markers: ᴹ ᴴ ᶠ ᴿ ᴸ
        return firstWord.replacingOccurrences(of: "[ᴹᴴᶠᴿᴸ]", with: "", options: .regularExpression)
    }

    /// Generates transcription options, prioritizing confusers with the same prefix
    private func generateTranscriptionOptions() -> [String] {
        let correctPrefix = transcriptionPrefix(consonant.transcription)

        // Find other consonants with the same prefix (confusers)
        let samePrefix = allConsonants
            .filter { $0.character != consonant.character }
            .filter { transcriptionPrefix($0.transcription) == correctPrefix }
            .shuffled()

        // Find other consonants with different prefixes
        let differentPrefix = allConsonants
            .filter { $0.character != consonant.character }
            .filter { transcriptionPrefix($0.transcription) != correctPrefix }
            .shuffled()

        var wrongOptions: [String] = []

        // Add at least one confuser with the same prefix if available
        if let confuser = samePrefix.first {
            wrongOptions.append(confuser.transcription)
        }

        // Fill remaining slots (need 3 wrong answers total)
        let remaining = differentPrefix.map { $0.transcription }
        for transcription in remaining {
            if wrongOptions.count >= 3 { break }
            wrongOptions.append(transcription)
        }

        // If we still need more and have more same-prefix options, add them
        for consonant in samePrefix.dropFirst() {
            if wrongOptions.count >= 3 { break }
            wrongOptions.append(consonant.transcription)
        }

        // Add the correct answer
        var options = wrongOptions
        options.append(consonant.transcription)

        return options.shuffled()
    }
}

// MARK: - Card State

struct CardState {
    enum Step {
        case selectClass
        case selectInitial
        case selectFinal
        case selectTranscription
        case completed
    }

    var step: Step = .selectClass
    var selectedClass: ConsonantClass? = nil
    var selectedInitial: String? = nil
    var selectedFinal: String? = nil
    var selectedTranscription: String? = nil
}

extension CardState {
    func hasError(for consonant: Consonant) -> Bool {
        if let selected = selectedClass, selected != consonant.consonantClass {
            return true
        }
        if let selected = selectedInitial, selected != consonant.initialSound {
            return true
        }
        if let selected = selectedFinal, selected != consonant.finalSound {
            return true
        }
        if let selected = selectedTranscription, selected != consonant.transcription {
            return true
        }
        return false
    }
}

#Preview {
    let consonants = Consonant.loadAll()
    return NavigationStack {
        if let first = consonants.first {
            ConsonantFlashcardView(
                consonant: first,
                allConsonants: consonants,
                onViewInReference: { _ in },
                onNext: {},
                onPrevious: {}
            )
        } else {
            Text("No consonant data")
        }
    }
}

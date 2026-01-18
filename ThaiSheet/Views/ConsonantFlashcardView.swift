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
        FlashcardResultCard(
            showResult: cardState.step == .completed,
            hasError: cardState.hasError(for: consonant)
        ) {
            VStack(spacing: 12) {
                // Main character with swipe gestures for navigation and reveal
                NavigableTapArea(
                    onPrevious: handlePrevious,
                    onNext: handleNext,
                    onReveal: cardState.step != .completed ? { completeCardEarly() } : nil
                ) {
                    Text(consonant.character)
                        .font(.system(size: 100))
                        .minimumScaleFactor(0.5)
                }
                .frame(height: 160)

                // Action buttons
                HStack(spacing: 20) {
                    // View in Reference button
                    Button {
                        onViewInReference?(consonant.character)
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
                        Button {
                            AudioPlayer.shared.playConsonantSound(for: consonant.character)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2.fill")
                                Text("Play")
                            }
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                        }
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
                    selectedValue: cardState.selectedClass?.rawValue.capitalized,
                    correctValue: consonant.consonantClass.rawValue.capitalized,
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
        VStack(spacing: 16) {
            Text("Select the class")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(ConsonantClass.allCases, id: \.self) { classType in
                    Button {
                        cardState.selectedClass = classType
                        cardState.step = .selectInitial
                    } label: {
                        Text(classType.rawValue.capitalized)
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Initial Sound Selection

    private var initialSoundSelectionView: some View {
        VStack(spacing: 16) {
            selectionHeader(title: "Select the initial sound") {
                cardState.selectedClass = nil
                cardState.step = .selectClass
            }

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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Final Sound Selection

    private var finalSoundSelectionView: some View {
        VStack(spacing: 16) {
            selectionHeader(title: "Select the final sound") {
                cardState.selectedInitial = nil
                cardState.step = .selectInitial
            }

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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Transcription Selection

    private var transcriptionSelectionView: some View {
        VStack(spacing: 16) {
            selectionHeader(title: "Select the transcription") {
                cardState.selectedFinal = nil
                cardState.step = .selectFinal
            }

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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Selection Helpers

    private func selectionHeader(title: String, onBack: @escaping () -> Void) -> some View {
        HStack {
            Button {
                onBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }

            Spacer()

            Text(title)
                .font(.headline)

            Spacer()

            // Invisible spacer for centering
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .font(.subheadline)
            .opacity(0)
        }
    }

    // MARK: - Card Completion

    private func completeCard() {
        cardState.step = .completed
        // Record result: correct if no errors were made
        let wasCorrect = !cardState.hasError(for: consonant)
        onComplete?(wasCorrect)
        AudioPlayer.shared.playConsonantSound(for: consonant.character)
    }

    private func completeCardEarly() {
        cardState.step = .completed
        // Revealed early = not answered correctly
        onComplete?(false)
        AudioPlayer.shared.playConsonantSound(for: consonant.character)
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
        // Get unique initial sounds from all consonants
        let allInitialSounds = Set(allConsonants.map { $0.initialSound })
        var initialOptions = Array(allInitialSounds.filter { $0 != consonant.initialSound }.shuffled().prefix(7))
        initialOptions.append(consonant.initialSound)
        initialSoundOptions = initialOptions.shuffled()

        // Get unique final sounds from all consonants
        let allFinalSounds = Set(allConsonants.map { $0.finalSound })
        var finalOptions = Array(allFinalSounds.filter { $0 != consonant.finalSound }.shuffled().prefix(3))
        finalOptions.append(consonant.finalSound)
        finalSoundOptions = finalOptions.shuffled()

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

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            if index < result.positions.count {
                let position = result.positions[index]
                subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
            }
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))

            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

#Preview {
    NavigationStack {
        ConsonantFlashcardView(
            consonant: Consonant.loadAll().first!,
            allConsonants: Consonant.loadAll(),
            onViewInReference: { _ in },
            onNext: {},
            onPrevious: {}
        )
    }
}

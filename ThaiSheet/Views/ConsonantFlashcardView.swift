//
//  ConsonantFlashcardView.swift
//  ThaiSheet
//

import SwiftUI

struct ConsonantFlashcardView: View {
    let consonants: [Consonant]
    @Binding var currentIndex: Int
    @Binding var startingConsonant: String?
    var onViewInReference: ((String) -> Void)?
    var onNextCard: (() -> Void)?

    @State private var cardState = CardState()

    // Generated options for current card
    @State private var initialSoundOptions: [String] = []
    @State private var finalSoundOptions: [String] = []
    @State private var transcriptionOptions: [String] = []

    var currentConsonant: Consonant? {
        guard currentIndex < consonants.count else { return nil }
        return consonants[currentIndex]
    }

    var body: some View {
        if let consonant = currentConsonant {
            ScrollView {
                VStack(spacing: 20) {
                    // Consonant display with status indicator
                    consonantCard(consonant: consonant)

                    // Summary section
                    summarySection(consonant: consonant)

                    // Selection area (changes based on current step)
                    selectionArea(consonant: consonant)
                }
                .padding()
            }
            .onAppear {
                // If starting at a specific consonant, find its index
                if let startChar = startingConsonant,
                   let index = consonants.firstIndex(where: { $0.character == startChar }) {
                    currentIndex = index
                    startingConsonant = nil  // Clear after using
                }
                generateOptions(for: consonant)
            }
            .onChange(of: startingConsonant) { _, newValue in
                // Handle navigation from Reference while already visible
                if let startChar = newValue,
                   let index = consonants.firstIndex(where: { $0.character == startChar }) {
                    currentIndex = index
                    cardState = CardState()  // Reset card state
                    startingConsonant = nil
                    if let newConsonant = currentConsonant {
                        generateOptions(for: newConsonant)
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "No Consonants",
                systemImage: "character.book.closed",
                description: Text("No consonants available")
            )
        }
    }

    // MARK: - Consonant Card

    private func consonantCard(consonant: Consonant) -> some View {
        VStack(spacing: 12) {
            // Main character with left/right tap zones for navigation
            NavigableTapArea(onPrevious: goToPreviousCard, onNext: goToNextCard) {
                ZStack {
                    if cardState.step == .completed {
                        FlashcardStatusRing(hasError: cardState.hasError(for: consonant))
                    }

                    Text(consonant.character)
                        .font(.system(size: 100))
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(height: 160)

            // Card type label
            Text("Consonant")
                .font(.caption)
                .foregroundColor(.secondary)

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
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    // MARK: - Summary Section

    private func summarySection(consonant: Consonant) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FlashcardSummaryHeader(
                showReveal: cardState.step != .completed,
                onReveal: { completeCardEarly(consonant: consonant) }
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
    private func selectionArea(consonant: Consonant) -> some View {
        switch cardState.step {
        case .selectClass:
            classSelectionView(consonant: consonant)
        case .selectInitial:
            initialSoundSelectionView(consonant: consonant)
        case .selectFinal:
            finalSoundSelectionView(consonant: consonant)
        case .selectTranscription:
            transcriptionSelectionView(consonant: consonant)
        case .completed:
            nextCardButton
        }
    }

    // MARK: - Class Selection

    private func classSelectionView(consonant: Consonant) -> some View {
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

    private func initialSoundSelectionView(consonant: Consonant) -> some View {
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

    private func finalSoundSelectionView(consonant: Consonant) -> some View {
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

    private func transcriptionSelectionView(consonant: Consonant) -> some View {
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
                        completeCard(consonant: consonant)
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

    private func completeCard(consonant: Consonant) {
        cardState.step = .completed
        AudioPlayer.shared.playConsonantSound(for: consonant.character)
    }

    private func completeCardEarly(consonant: Consonant) {
        cardState.step = .completed
        AudioPlayer.shared.playConsonantSound(for: consonant.character)
    }

    // MARK: - Next Card Button

    private var nextCardButton: some View {
        FlashcardNextButton {
            goToNextCard()
        }
    }

    // MARK: - Actions

    private func goToNextCard() {
        // Reset state
        cardState = CardState()

        // Let parent handle navigation if callback provided
        if let onNextCard = onNextCard {
            onNextCard()
        } else {
            // Fallback: move to next card (loop back to start if at end)
            currentIndex = (currentIndex + 1) % consonants.count
        }

        // Generate new options
        if let consonant = currentConsonant {
            generateOptions(for: consonant)
        }
    }

    private func goToPreviousCard() {
        // Reset state
        cardState = CardState()

        // Move to previous card (loop to end if at start)
        currentIndex = (currentIndex - 1 + consonants.count) % consonants.count

        // Generate new options
        if let consonant = currentConsonant {
            generateOptions(for: consonant)
        }
    }

    private func generateOptions(for consonant: Consonant) {
        // Get unique initial sounds from all consonants
        let allInitialSounds = Set(consonants.map { $0.initialSound })
        var initialOptions = Array(allInitialSounds.filter { $0 != consonant.initialSound }.shuffled().prefix(7))
        initialOptions.append(consonant.initialSound)
        initialSoundOptions = initialOptions.shuffled()

        // Get unique final sounds from all consonants
        let allFinalSounds = Set(consonants.map { $0.finalSound })
        var finalOptions = Array(allFinalSounds.filter { $0 != consonant.finalSound }.shuffled().prefix(3))
        finalOptions.append(consonant.finalSound)
        finalSoundOptions = finalOptions.shuffled()

        // Get transcriptions from other consonants (3 wrong + 1 correct = 4 total)
        var transcriptionOpts = consonants
            .filter { $0.character != consonant.character }
            .shuffled()
            .prefix(3)
            .map { $0.transcription }
        transcriptionOpts.append(consonant.transcription)
        transcriptionOptions = Array(transcriptionOpts).shuffled()
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
            consonants: Consonant.loadAll(),
            currentIndex: .constant(0),
            startingConsonant: .constant(nil),
            onViewInReference: { _ in }
        )
    }
}

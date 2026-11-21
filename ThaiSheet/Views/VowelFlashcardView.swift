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
    @State private var showingDetails = false

    // Row-level override keyed by the parent vowel (applies to all forms), matching Reference.
    private var overrideItemID: String { FlashcardType.vowel.cardId(for: card.vowel.id) }
    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 72

    // Generated options for sound selection
    @State private var options = QuizOptionCache(value: [String]())

    private var optionContext: QuizOptionContext {
        QuizOptionContext(
            cardID: FlashcardType.vowel.cardId(for: card.id),
            romanization: RomanizationState.shared.scheme
        )
    }

    var body: some View {
        FlashcardLayout {
            vowelCardView
        } summary: {
            summarySection
        } question: {
            selectionArea
        }
        .onChange(of: optionContext, initial: true) { _, context in
            options.update(for: context) { generateOptions() }
        }
        .onChange(of: card.id) { _, _ in
            // Reset state when card changes
            cardState = VowelCardState()
        }
        .sheet(isPresented: $showingDetails) {
            VowelDetailSheet(
                vowel: card.vowel,
                formType: VowelFormVariant(duration: card.shownDuration, form: card.form),
                text: card.display,
                coversClosedForm: card.coversClosedForm
            )
        }
    }

    // MARK: - Vowel Card View

    private var vowelCardView: some View {
        FlashcardFace(
            showResult: currentStep == .completed,
            hasError: cardState.hasError(for: card),
            soundType: .vowel,
            soundKey: primaryWord ?? "",
            overrideItemID: overrideItemID,
            // Each example word carries its own speaker instead.
            showsPlayAction: false,
            onViewInReference: { onViewInReference?(card.display) },
            onShowDetails: { showingDetails = true },
            onPrevious: handlePrevious,
            onNext: handleNext
        ) {
            VStack(spacing: 4) {
                if currentStep == .completed, card.promptsWithWord, let word = primaryWord {
                    exampleButton(word: word, font: .system(size: glyphSize), primary: true)
                } else {
                    Text(card.prompt)
                        .font(.system(size: glyphSize))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }

                if currentStep == .completed {
                    revealedAnswer
                }
            }
        }
    }

    /// The word whose audio the card plays: its first example.
    private var primaryWord: String? {
        card.revealedSamples.first?.word.word
    }

    /// Under the prompt after reveal: the written form for a word prompt
    /// (whose word is already the prompt), else the example words, each with
    /// its own speaker. A card covering both forms shows one per form.
    @ViewBuilder
    private var revealedAnswer: some View {
        if card.promptsWithWord, card.pronunciationWord != nil {
            Text(card.bareForm)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } else if card.coversClosedForm {
            HStack(spacing: 24) {
                ForEach(card.revealedSamples) { sample in
                    exampleButton(word: sample.word.word, caption: sample.form.label, font: .title)
                }
            }
        } else if let word = primaryWord {
            exampleButton(word: word, font: .largeTitle)
        }
    }

    /// An example word with a speaker beside it; tapping plays the word.
    private func exampleButton(
        word: String,
        caption: String? = nil,
        font: Font,
        primary: Bool = false
    ) -> some View {
        let hasSound = audioPlayer.hasSound(.vowel, key: word)
        return Button {
            play(word)
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text(word)
                        .font(font)
                        .foregroundStyle(primary ? Color.primary : Color.secondary)
                    Image(systemName: hasSound ? "speaker.wave.2.fill" : "speaker.slash")
                        .font(.body)
                        .foregroundStyle(hasSound ? Color.accentColor : Color.secondary)
                        .accessibilityHidden(true)
                }
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .buttonStyle(.plain)
        .disabled(!hasSound)
        .accessibilityLabel(Text(verbatim: caption.map { "\(word), \($0)" } ?? word))
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlashcardSummaryHeader(
                showReveal: currentStep != .completed,
                onReveal: { completeCardEarly() }
            )

            FlashcardSummaryGrid {
                if card.asksDuration {
                    FlashcardSummaryRow(
                        label: "Duration",
                        selectedValue: cardState.selectedDuration?.label,
                        correctValue: card.shownDuration.label,
                        showResult: currentStep == .completed,
                        alternativeCorrectValue: card.alternativeDuration?.label
                    )
                }
                if card.asksForm {
                    FlashcardSummaryRow(
                        label: "Form",
                        selectedValue: cardState.selectedForm?.label,
                        correctValue: card.formAnswer.label,
                        showResult: currentStep == .completed
                    )
                }
                FlashcardSummaryRow(
                    label: "Sound",
                    selectedValue: cardState.selectedSound,
                    correctValue: card.vowel.sound,
                    showResult: currentStep == .completed,
                    // Grades on the row label, shows the card's own form
                    display: { [card] value in
                        value == card.vowel.sound
                            ? card.renderedSound(as: RomanizationState.shared.scheme)
                            : value.romanizedVowelLabel
                    }
                )

                // Show notes if available and card is completed
                if currentStep == .completed, !card.notes.isEmpty {
                    Divider()
                    Text(card.notes.joined(separator: "\n\n"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Selection Area

    /// The step on screen. A fresh card starts at the first question it asks.
    private var currentStep: VowelCardState.Step {
        cardState.step ?? card.firstStep
    }

    @ViewBuilder
    private var selectionArea: some View {
        switch currentStep {
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
                        cardState.step = card.asksForm ? .selectForm : .selectSound
                    }
                }
            }
        }
    }

    // MARK: - Form Selection

    private var formSelectionView: some View {
        FlashcardStepSection(title: "Select the form", onBack: card.asksDuration ? {
            cardState.selectedDuration = nil
            cardState.step = .selectDuration
        } : nil) {
            HStack(spacing: 12) {
                ForEach(VowelCard.FormAnswer.allCases, id: \.self) { form in
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
        FlashcardStepSection(title: "Select the sound", onBack: soundStepBack) {
            // 2 rows of 4 buttons
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(options.value, id: \.self) { sound in
                    FlashcardGridButton(label: sound.romanizedVowelLabel) {
                        cardState.selectedSound = sound
                        completeCard()
                    }
                }
            }
        }
    }

    /// Back from the sound step returns to the previous question the card asks.
    private var soundStepBack: (() -> Void)? {
        if card.asksForm {
            return {
                cardState.selectedForm = nil
                cardState.step = .selectForm
            }
        }
        if card.asksDuration {
            return {
                cardState.selectedDuration = nil
                cardState.step = .selectDuration
            }
        }
        return nil
    }

    // MARK: - Card Completion

    private func completeCard(revealed: Bool = false) {
        guard currentStep != .completed else { return }
        cardState.step = .completed
        // Revealed early counts as incorrect; otherwise correct if no errors were made
        onComplete?(revealed ? false : !cardState.hasError(for: card))
        playVowelSound()
    }

    private func completeCardEarly() {
        completeCard(revealed: true)
    }

    private func playVowelSound() {
        guard let word = primaryWord else { return }
        play(word)
    }

    private func play(_ word: String) {
        if audioPlayer.hasSound(.vowel, key: word) {
            audioPlayer.play(.vowel, key: word, itemID: overrideItemID)
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

    private func generateOptions() -> [String] {
        QuizOptions.pickDistinct(
            correct: card.vowel.sound,
            from: allVowels.map { $0.sound },
            wrongCount: 7,
            context: .vowelLabel
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

    /// Nil until the first answer: the view then shows the card's first step.
    var step: Step? = nil
    var selectedDuration: VowelCard.VowelDuration? = nil
    var selectedForm: VowelCard.FormAnswer? = nil
    var selectedSound: String? = nil
}

extension VowelCard {
    /// The first question this card asks.
    var firstStep: VowelCardState.Step {
        if asksDuration { return .selectDuration }
        return asksForm ? .selectForm : .selectSound
    }
}

extension VowelCardState {
    func hasError(for card: VowelCard) -> Bool {
        // For duration: accept both if card accepts both durations
        if let selected = selectedDuration, selected != card.duration {
            if !card.acceptsBothDurations {
                return true
            }
        }
        if let selected = selectedForm, selected != card.formAnswer {
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

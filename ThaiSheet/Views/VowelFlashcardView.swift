//
//  VowelFlashcardView.swift
//  ThaiSheet
//

import SwiftUI

// Represents a single vowel form card
struct VowelCard: Identifiable {
    let vowel: Vowel
    let duration: VowelDuration
    let form: VowelFormType
    let display: String

    var id: String { display }

    enum VowelDuration: String, CaseIterable {
        case short = "Short"
        case long = "Long"
    }

    enum VowelFormType: String, CaseIterable {
        case closed = "Closed"
        case open = "Open"
    }

    static func allCards(from vowels: [Vowel]) -> [VowelCard] {
        var cards: [VowelCard] = []
        for vowel in vowels {
            if let form = vowel.short.closed {
                cards.append(VowelCard(vowel: vowel, duration: .short, form: .closed, display: form))
            }
            if let form = vowel.short.open {
                cards.append(VowelCard(vowel: vowel, duration: .short, form: .open, display: form))
            }
            if let form = vowel.long.closed {
                cards.append(VowelCard(vowel: vowel, duration: .long, form: .closed, display: form))
            }
            if let form = vowel.long.open {
                cards.append(VowelCard(vowel: vowel, duration: .long, form: .open, display: form))
            }
        }
        return cards
    }
}

struct VowelFlashcardView: View {
    let card: VowelCard
    let allVowels: [Vowel]  // For generating quiz options
    var onViewInReference: ((String) -> Void)?
    let onNext: () -> Void
    let onPrevious: () -> Void

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
        VStack(spacing: 12) {
            // Main character with left/right tap zones for navigation
            NavigableTapArea(onPrevious: handlePrevious, onNext: handleNext) {
                ZStack {
                    if cardState.step == .completed {
                        FlashcardStatusRing(hasError: cardState.hasError(for: card))
                    }

                    Text(card.display.replacingOccurrences(of: "-", with: ""))
                        .font(.system(size: 72))
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(height: 160)

            // Card type label
            Text("Vowel")
                .font(.caption)
                .foregroundColor(.secondary)

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
                    let hasSound = AudioPlayer.shared.hasVowelSound(for: card.display)
                    Button {
                        playVowelSound()
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
                    selectedValue: cardState.selectedDuration?.rawValue,
                    correctValue: card.duration.rawValue,
                    showResult: cardState.step == .completed,
                    labelWidth: 70
                )
                FlashcardSummaryRow(
                    label: "Form",
                    selectedValue: cardState.selectedForm?.rawValue,
                    correctValue: card.form.rawValue,
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
        VStack(spacing: 16) {
            Text("Select the duration")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(VowelCard.VowelDuration.allCases, id: \.self) { duration in
                    Button {
                        cardState.selectedDuration = duration
                        cardState.step = .selectForm
                    } label: {
                        Text(duration.rawValue)
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

    // MARK: - Form Selection

    private var formSelectionView: some View {
        VStack(spacing: 16) {
            selectionHeader(title: "Select the form") {
                cardState.selectedDuration = nil
                cardState.step = .selectDuration
            }

            HStack(spacing: 12) {
                ForEach(VowelCard.VowelFormType.allCases, id: \.self) { form in
                    Button {
                        cardState.selectedForm = form
                        cardState.step = .selectSound
                    } label: {
                        Text(form.rawValue)
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

    // MARK: - Sound Selection

    private var soundSelectionView: some View {
        VStack(spacing: 16) {
            selectionHeader(title: "Select the sound") {
                cardState.selectedForm = nil
                cardState.step = .selectForm
            }

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
        playVowelSound()
    }

    private func completeCardEarly() {
        cardState.step = .completed
        playVowelSound()
    }

    private func playVowelSound() {
        if AudioPlayer.shared.hasVowelSound(for: card.display) {
            AudioPlayer.shared.playVowelSound(for: card.display)
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
        // Get unique sounds from all vowels
        let allSounds = Set(allVowels.map { $0.sound })
        var options = Array(allSounds.filter { $0 != card.vowel.sound }.shuffled().prefix(7))
        options.append(card.vowel.sound)
        soundOptions = options.shuffled()
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
        if let selected = selectedDuration, selected != card.duration {
            return true
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
    NavigationStack {
        VowelFlashcardView(
            card: VowelCard.allCards(from: Vowel.loadAll()).first!,
            allVowels: Vowel.loadAll(),
            onViewInReference: { _ in },
            onNext: {},
            onPrevious: {}
        )
    }
}

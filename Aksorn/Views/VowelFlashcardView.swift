//
//  VowelFlashcardView.swift
//  Aksorn
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
    let cards: [VowelCard]
    let allVowels: [Vowel]
    @Binding var startingVowel: String?
    var onViewInReference: ((String) -> Void)?
    var onNextCard: (() -> Void)?

    @State private var currentIndex: Int = 0
    @State private var cardState = VowelCardState()

    // Generated options for sound selection
    @State private var soundOptions: [String] = []

    var currentCard: VowelCard? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var body: some View {
        if let card = currentCard {
            ScrollView {
                VStack(spacing: 20) {
                    // Vowel display with status indicator
                    vowelCardView(card: card)

                    // Summary section
                    summarySection(card: card)

                    // Selection area (changes based on current step)
                    selectionArea(card: card)

                    // Progress indicator
                    progressIndicator
                }
                .padding()
            }
            .onAppear {
                if let startVowel = startingVowel,
                   let index = cards.firstIndex(where: { $0.display == startVowel }) {
                    currentIndex = index
                    startingVowel = nil
                }
                generateOptions(for: card)
            }
            .onChange(of: startingVowel) { _, newValue in
                if let startVowel = newValue,
                   let index = cards.firstIndex(where: { $0.display == startVowel }) {
                    currentIndex = index
                    cardState = VowelCardState()
                    startingVowel = nil
                    if let newCard = currentCard {
                        generateOptions(for: newCard)
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "No Vowels",
                systemImage: "character.book.closed",
                description: Text("No vowels available")
            )
        }
    }

    // MARK: - Vowel Card View

    private func vowelCardView(card: VowelCard) -> some View {
        VStack(spacing: 12) {
            ZStack {
                // Status ring
                if cardState.step == .completed {
                    Circle()
                        .stroke(cardState.hasError(for: card) ? Color.red : Color.green, lineWidth: 4)
                        .frame(width: 160, height: 160)
                }

                Text(card.display)
                    .font(.system(size: 72))
                    .minimumScaleFactor(0.5)
            }

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

    private func summarySection(card: VowelCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 6) {
                summaryRow(
                    label: "Duration",
                    selectedValue: cardState.selectedDuration?.rawValue,
                    correctValue: card.duration.rawValue,
                    isCorrect: cardState.selectedDuration == card.duration,
                    wasSelected: cardState.selectedDuration != nil,
                    showResult: cardState.step == .completed
                )
                summaryRow(
                    label: "Form",
                    selectedValue: cardState.selectedForm?.rawValue,
                    correctValue: card.form.rawValue,
                    isCorrect: cardState.selectedForm == card.form,
                    wasSelected: cardState.selectedForm != nil,
                    showResult: cardState.step == .completed
                )
                summaryRow(
                    label: "Sound",
                    selectedValue: cardState.selectedSound,
                    correctValue: card.vowel.sound,
                    isCorrect: cardState.selectedSound == card.vowel.sound,
                    wasSelected: cardState.selectedSound != nil,
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
                .frame(width: 70, alignment: .leading)

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
    private func selectionArea(card: VowelCard) -> some View {
        switch cardState.step {
        case .selectDuration:
            durationSelectionView(card: card)
        case .selectForm:
            formSelectionView(card: card)
        case .selectSound:
            soundSelectionView(card: card)
        case .completed:
            nextCardButton
        }
    }

    // MARK: - Duration Selection

    private func durationSelectionView(card: VowelCard) -> some View {
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

    private func formSelectionView(card: VowelCard) -> some View {
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

            selectionFooter {
                completeCardEarly()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Sound Selection

    private func soundSelectionView(card: VowelCard) -> some View {
        VStack(spacing: 16) {
            selectionHeader(title: "Select the sound") {
                cardState.selectedForm = nil
                cardState.step = .selectForm
            }

            FlowLayout(spacing: 10) {
                ForEach(soundOptions, id: \.self) { sound in
                    Button {
                        cardState.selectedSound = sound
                        completeCard()
                    } label: {
                        Text(sound)
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            selectionFooter {
                completeCardEarly()
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

    private func selectionFooter(skipAction: @escaping () -> Void) -> some View {
        Button {
            skipAction()
        } label: {
            Text("Complete card now")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
        guard let card = currentCard else { return }
        // Try to play sound for the current form, or find one that exists
        if AudioPlayer.shared.hasVowelSound(for: card.display) {
            AudioPlayer.shared.playVowelSound(for: card.display)
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
        cardState = VowelCardState()
        currentIndex = (currentIndex + 1) % cards.count
        if let newCard = currentCard {
            generateOptions(for: newCard)
        }

        // Notify parent to switch card type (consonant/vowel alternation)
        onNextCard?()
    }

    private func generateOptions(for card: VowelCard) {
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
            cards: VowelCard.allCards(from: Vowel.loadAll()),
            allVowels: Vowel.loadAll(),
            startingVowel: .constant(nil),
            onViewInReference: { _ in },
            onNextCard: { }
        )
    }
}

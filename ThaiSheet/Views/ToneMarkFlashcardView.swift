//
//  ToneMarkFlashcardView.swift
//  ThaiSheet
//

import SwiftUI

// Represents a single tone mark card with a random consonant
struct ToneMarkCard: Identifiable {
    let toneMark: ToneMark
    let consonant: Consonant
    let consonantClass: ConsonantClassType
    let display: String
    let correctTone: String

    var id: String { display }

    enum ConsonantClassType: String, CaseIterable {
        case low = "Low"
        case midHigh = "Mid/High"
    }

    static func allCards(from toneMarks: [ToneMark], consonants: [Consonant]) -> [ToneMarkCard] {
        // Filter for common consonants only
        let commonConsonants = consonants.filter { $0.usage == .common }

        var cards: [ToneMarkCard] = []
        for toneMark in toneMarks {
            for consonant in commonConsonants {
                // Determine if this consonant is low or mid/high class
                let isLowClass = consonant.consonantClass == .low
                let correctTone = isLowClass ? toneMark.onLowConsonant : toneMark.onMidHighConsonant

                // Skip if this tone mark doesn't apply to this consonant class
                if correctTone == "n/a" {
                    continue
                }

                // Display: consonant + tone mark + า
                let display = consonant.character + toneMark.mark + "า"

                cards.append(ToneMarkCard(
                    toneMark: toneMark,
                    consonant: consonant,
                    consonantClass: isLowClass ? .low : .midHigh,
                    display: display,
                    correctTone: correctTone
                ))
            }
        }
        return cards.shuffled()
    }
}

struct ToneMarkFlashcardView: View {
    let cards: [ToneMarkCard]
    @Binding var currentIndex: Int
    @Binding var startingToneMark: String?
    var onViewInReference: ((String) -> Void)?

    @State private var cardState = ToneMarkCardState()

    // All possible tones for selection
    private let toneOptions = ["Low", "Mid", "High", "Falling", "Rising"]

    var currentCard: ToneMarkCard? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var body: some View {
        if let card = currentCard {
            ScrollView {
                VStack(spacing: 20) {
                    // Tone mark display with status indicator
                    toneMarkCardView(card: card)

                    // Summary section
                    summarySection(card: card)

                    // Selection area
                    selectionArea(card: card)
                }
                .padding()
            }
            .onAppear {
                if let startMark = startingToneMark,
                   let index = cards.firstIndex(where: { $0.display == startMark }) {
                    currentIndex = index
                    startingToneMark = nil
                }
            }
            .onChange(of: startingToneMark) { _, newValue in
                if let startMark = newValue,
                   let index = cards.firstIndex(where: { $0.display == startMark }) {
                    currentIndex = index
                    cardState = ToneMarkCardState()
                    startingToneMark = nil
                }
            }
        } else {
            ContentUnavailableView(
                "No Tone Marks",
                systemImage: "character.book.closed",
                description: Text("No tone marks available")
            )
        }
    }

    // MARK: - Tone Mark Card View

    private func toneMarkCardView(card: ToneMarkCard) -> some View {
        VStack(spacing: 12) {
            // Main character with left/right tap zones for navigation
            NavigableTapArea(onPrevious: goToPreviousCard, onNext: goToNextCard) {
                ZStack {
                    if cardState.step == .completed {
                        FlashcardStatusRing(hasError: cardState.hasError(for: card))
                    }

                    Text(card.display)
                        .font(.system(size: 100))
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(height: 160)

            // Card type label
            Text("Tone mark")
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
                    let hasSound = AudioPlayer.shared.hasToneMarkSound(for: card.display)
                    Button {
                        AudioPlayer.shared.playToneMarkSound(for: card.display)
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

    private func summarySection(card: ToneMarkCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FlashcardSummaryHeader(
                showReveal: cardState.step != .completed,
                onReveal: { completeCard(card: card) }
            )

            VStack(spacing: 6) {
                FlashcardSummaryRow(
                    label: "Class",
                    selectedValue: cardState.selectedClass,
                    correctValue: card.consonantClass.rawValue,
                    showResult: cardState.step == .completed
                )
                FlashcardSummaryRow(
                    label: "Tone",
                    selectedValue: cardState.selectedTone,
                    correctValue: card.correctTone,
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
    private func selectionArea(card: ToneMarkCard) -> some View {
        switch cardState.step {
        case .selectClass:
            classSelectionView(card: card)
        case .selectTone:
            toneSelectionView(card: card)
        case .completed:
            nextCardButton
        }
    }

    // MARK: - Class Selection

    private let classOptions = ["Low", "Mid/High"]

    private func classSelectionView(card: ToneMarkCard) -> some View {
        VStack(spacing: 16) {
            Text("Select the consonant class")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(classOptions, id: \.self) { classOption in
                    Button {
                        cardState.selectedClass = classOption
                        cardState.step = .selectTone
                    } label: {
                        Text(classOption)
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

    private func toneSelectionView(card: ToneMarkCard) -> some View {
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

    private func completeCard(card: ToneMarkCard) {
        cardState.step = .completed
        if AudioPlayer.shared.hasToneMarkSound(for: card.display) {
            AudioPlayer.shared.playToneMarkSound(for: card.display)
        }
    }

    // MARK: - Next Card Button

    private var nextCardButton: some View {
        FlashcardNextButton {
            goToNextCard()
        }
    }

    // MARK: - Actions

    private func goToNextCard() {
        cardState = ToneMarkCardState()
        currentIndex = (currentIndex + 1) % cards.count
    }

    private func goToPreviousCard() {
        cardState = ToneMarkCardState()
        currentIndex = (currentIndex - 1 + cards.count) % cards.count
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
    var selectedClass: String? = nil
    var selectedTone: String? = nil
}

extension ToneMarkCardState {
    func hasError(for card: ToneMarkCard) -> Bool {
        if let selected = selectedClass, selected != card.consonantClass.rawValue {
            return true
        }
        if let selected = selectedTone, selected != card.correctTone {
            return true
        }
        return false
    }
}

#Preview {
    NavigationStack {
        ToneMarkFlashcardView(
            cards: ToneMarkCard.allCards(from: ToneMark.loadAll(), consonants: Consonant.loadAll()),
            currentIndex: .constant(0),
            startingToneMark: .constant(nil),
            onViewInReference: { _ in }
        )
    }
}

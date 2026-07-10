//
//  FlashcardComponents.swift
//  ThaiSheet
//
//  Shared components for flashcard views
//

import SwiftUI

// MARK: - Swipeable Card Area

/// A container that detects horizontal swipes for card navigation
/// - Swipe left: next card
/// - Swipe right: previous card
struct NavigableTapArea<Content: View>: View {
    let onPrevious: () -> Void
    let onNext: () -> Void
    @ViewBuilder let content: () -> Content

    /// Horizontal travel needed to register a card swipe; shorter drags are
    /// treated as accidental
    private let swipeThreshold: CGFloat = 50
    /// Drag distance before the gesture activates at all, so quiz-button taps
    /// with slight movement don't get swallowed
    private let swipeActivationDistance: CGFloat = 30

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: swipeActivationDistance, coordinateSpace: .local)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height

                        // Only handle horizontal swipes (avoid conflict with ScrollView)
                        guard abs(horizontal) > abs(vertical) else { return }

                        if horizontal < -swipeThreshold {
                            onNext()
                        } else if horizontal > swipeThreshold {
                            onPrevious()
                        }
                    }
            )
    }
}

// MARK: - Card Face

/// The top card of every flashcard: result-tinted background, swipeable
/// display area, and the Reference / Play button row.
struct FlashcardFace<Content: View>: View {
    let showResult: Bool
    let hasError: Bool
    let soundType: SoundType
    let soundKey: String
    var displayHeight: CGFloat = 160
    var onViewInReference: (() -> Void)?
    let onPrevious: () -> Void
    let onNext: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.audioPlayer) private var audioPlayer
    /// Grows the display area with Dynamic Type so scaled glyphs don't clip
    @ScaledMetric(relativeTo: .largeTitle) private var displayScale: CGFloat = 1

    var body: some View {
        FlashcardResultCard(showResult: showResult, hasError: hasError) {
            VStack(spacing: 12) {
                NavigableTapArea(onPrevious: onPrevious, onNext: onNext) {
                    content()
                }
                .frame(height: displayHeight * displayScale)

                HStack(spacing: 20) {
                    Button {
                        onViewInReference?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "book")
                            Text("Reference")
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                    }

                    // Speaker button (only when completed)
                    if showResult {
                        let hasSound = audioPlayer.hasSound(soundType, key: soundKey)
                        Button {
                            audioPlayer.play(soundType, key: soundKey)
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
}

// MARK: - Step Section

/// Container for one question step: title (with optional Back button) above
/// the selection controls, on the standard gray rounded background.
struct FlashcardStepSection<Content: View>: View {
    let title: LocalizedStringKey
    var onBack: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 16) {
            if let onBack {
                FlashcardStepHeader(title: title, onBack: onBack)
            } else {
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

/// Step title with a Back button, kept centered by a hidden mirror of the button
struct FlashcardStepHeader: View {
    let title: LocalizedStringKey
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                backLabel
                    .foregroundColor(.accentColor)
            }

            Spacer()

            Text(title)
                .font(.headline)

            Spacer()

            // Invisible spacer for centering
            backLabel
                .opacity(0)
        }
    }

    private var backLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "chevron.left")
            Text("Back")
        }
        .font(.subheadline)
    }
}

// MARK: - Localized Option

/// A selection option whose `value` is the data identifier (matching JSON)
/// and whose `label` is its localized display text.
struct LocalizedOption: Identifiable {
    let value: String
    var label: String { String(localized: String.LocalizationValue(value), bundle: .appLanguage) }
    var id: String { value }
}

// MARK: - Quiz Options

enum QuizOptions {
    /// Returns up to `wrongCount` random wrong answers plus the correct one, shuffled.
    static func pick(correct: String, from all: some Sequence<String>, wrongCount: Int) -> [String] {
        var options = Array(Set(all).subtracting([correct]).shuffled().prefix(wrongCount))
        options.append(correct)
        return options.shuffled()
    }
}

// MARK: - Next Card Button

struct FlashcardNextButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
}

// MARK: - Summary Header

/// Header for the summary section with optional Reveal button
struct FlashcardSummaryHeader: View {
    let showReveal: Bool
    let onReveal: () -> Void

    var body: some View {
        HStack {
            Spacer()

            if showReveal {
                Button(action: onReveal) {
                    Text("Reveal")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

// MARK: - Summary Row

/// A single row in the summary section showing label and value.
/// A `GridRow`, so the enclosing `Grid` sizes the label column to the
/// longest label — no fixed widths that wrap in other languages or at
/// larger Dynamic Type sizes.
struct FlashcardSummaryRow: View {
    let label: LocalizedStringKey
    let selectedValue: String?
    let correctValue: String
    let showResult: Bool
    var alternativeCorrectValue: String? = nil

    private var isCorrect: Bool {
        selectedValue == correctValue ||
        (alternativeCorrectValue != nil && selectedValue == alternativeCorrectValue)
    }

    private var wasSelected: Bool {
        selectedValue != nil
    }

    var body: some View {
        GridRow {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .gridColumnAlignment(.leading)

            HStack {
                valueContent
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var valueContent: some View {
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
    }
}

/// Container for summary rows: a two-column grid whose label column hugs
/// the longest label
struct FlashcardSummaryGrid<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            content()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Result Card Wrapper

/// Wraps card content with background tint and shake animation for results
struct FlashcardResultCard<Content: View>: View {
    let showResult: Bool
    let hasError: Bool
    @ViewBuilder let content: () -> Content

    @State private var shakeTrigger = 0

    private enum ShakePhase: CaseIterable {
        case start, right, left, rightSmall, leftSmall, end

        var offset: CGFloat {
            switch self {
            case .start, .end: return 0
            case .right: return 10
            case .left: return -10
            case .rightSmall: return 5
            case .leftSmall: return -5
            }
        }
    }

    var body: some View {
        PhaseAnimator(ShakePhase.allCases, trigger: shakeTrigger) { phase in
            content()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(backgroundColor)
                )
                .offset(x: phase.offset)
        } animation: { _ in
            .easeInOut(duration: 0.08)
        }
        .onChange(of: showResult) { _, isCompleted in
            if isCompleted && hasError {
                shakeTrigger += 1
            }
        }
    }

    private var backgroundColor: Color {
        guard showResult else { return Color(.systemGray6) }
        return hasError ? Color.red.opacity(0.15) : Color.green.opacity(0.15)
    }
}

// MARK: - Selection Button

/// Standard button style for flashcard selection options
struct FlashcardSelectionButton: View {
    let label: String
    var background: AnyShapeStyle = AnyShapeStyle(Color(.systemGray5))
    var font: Font = .body.weight(.medium)
    /// Spoken name when the visual label is a symbol (e.g. tone diacritics)
    var accessibilityLabel: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(font)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(background)
                .foregroundColor(.primary)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? label)
    }
}

// MARK: - Grid Selection Button

/// Smaller button style for grid layouts
struct FlashcardGridButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stage Indicator

/// Shows the SRS progress indicator for the current card: 8 dots with stage name
struct StageIndicatorView: View {
    let stage: SRSStage
    let isCapped: Bool

    /// The stage at which partial testing caps advancement
    private static let cappedStage: SRSStage = .familiar2

    var body: some View {
        VStack(spacing: 2) {
            // 8 dots (Learning 1 through Mastered)
            stageDots(stage: stage, isCapped: isCapped)

            // Stage name with capped indicator
            stageLabel(stage: stage, isCapped: isCapped)
        }
    }

    // MARK: - Shared Components

    private func stageDots(stage: SRSStage, isCapped: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(1...8, id: \.self) { dotIndex in
                let isCurrent = dotIndex == stage.rawValue
                let isBeyondCap = isCapped && dotIndex > Self.cappedStage.rawValue

                Circle()
                    .fill(dotFillColor(isCurrent: isCurrent, isBeyondCap: isBeyondCap))
                    .frame(width: 8, height: 8)
                    .overlay {
                        // Show lock on capped dots
                        if isBeyondCap && !isCurrent {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 5))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    }
            }
        }
    }

    private func stageLabel(stage: SRSStage, isCapped: Bool) -> some View {
        HStack(spacing: 3) {
            Text(stage.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)

            if isCapped {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.orange)
            }
        }
    }

    private func dotFillColor(isCurrent: Bool, isBeyondCap: Bool) -> Color {
        if isCurrent {
            return Color.primary
        } else if isBeyondCap {
            return Color.gray.opacity(0.15)
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

// MARK: - Previews

#Preview("Stage Indicators") {
    VStack(spacing: 30) {
        // Stage indicators - not capped
        Text("Full Testing").font(.caption).foregroundColor(.secondary)
        ForEach([SRSStage.new, .learning1, .apprentice1, .familiar1, .confident, .mastered], id: \.rawValue) { stage in
            StageIndicatorView(stage: stage, isCapped: false)
        }

        Divider()

        // Stage indicators - capped
        Text("Partial Testing (Capped)").font(.caption).foregroundColor(.secondary)
        ForEach([SRSStage.learning1, .familiar1, .familiar2], id: \.rawValue) { stage in
            StageIndicatorView(stage: stage, isCapped: true)
        }
    }
    .padding()
}

#Preview("Components") {
    VStack(spacing: 20) {
        // Summary Header
        FlashcardSummaryHeader(showReveal: true) {
            print("Reveal tapped")
        }
        .padding(.horizontal)

        // Summary Rows
        FlashcardSummaryGrid {
            FlashcardSummaryRow(
                label: "Class",
                selectedValue: "Low",
                correctValue: "Low",
                showResult: true
            )
            FlashcardSummaryRow(
                label: "Initial",
                selectedValue: "k",
                correctValue: "ng",
                showResult: true
            )
            FlashcardSummaryRow(
                label: "Final",
                selectedValue: nil,
                correctValue: "ng",
                showResult: false
            )
        }
        .padding(.horizontal)

        // Selection Buttons
        HStack(spacing: 8) {
            FlashcardSelectionButton(label: "Low") {}
            FlashcardSelectionButton(label: "Mid") {}
            FlashcardSelectionButton(label: "High") {}
        }
        .padding(.horizontal)

        // Next Button
        FlashcardNextButton {
            print("Next tapped")
        }
        .padding(.horizontal)
    }
}

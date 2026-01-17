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
    var onReveal: (() -> Void)? = nil  // Not used currently (ScrollView conflicts with vertical swipes)
    @ViewBuilder let content: () -> Content

    private let swipeThreshold: CGFloat = 50

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
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

/// A single row in the summary section showing label and value
struct FlashcardSummaryRow: View {
    let label: String
    let selectedValue: String?
    let correctValue: String
    let showResult: Bool
    var labelWidth: CGFloat = 60

    private var isCorrect: Bool {
        selectedValue == correctValue
    }

    private var wasSelected: Bool {
        selectedValue != nil
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .leading)

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
}

// MARK: - Result Card Wrapper

/// Wraps card content with background tint and shake animation for results
struct FlashcardResultCard<Content: View>: View {
    let showResult: Bool
    let hasError: Bool
    @ViewBuilder let content: () -> Content

    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
            )
            .offset(x: shakeOffset)
            .onChange(of: showResult) { _, isCompleted in
                if isCompleted && hasError {
                    triggerShake()
                }
            }
    }

    private var backgroundColor: Color {
        guard showResult else { return Color(.systemGray6) }
        return hasError ? Color.red.opacity(0.15) : Color.green.opacity(0.15)
    }

    private func triggerShake() {
        let shakeDistance: CGFloat = 10
        let shakeDuration: Double = 0.08

        withAnimation(.easeInOut(duration: shakeDuration)) {
            shakeOffset = shakeDistance
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + shakeDuration) {
            withAnimation(.easeInOut(duration: shakeDuration)) {
                shakeOffset = -shakeDistance
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + shakeDuration * 2) {
            withAnimation(.easeInOut(duration: shakeDuration)) {
                shakeOffset = shakeDistance * 0.5
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + shakeDuration * 3) {
            withAnimation(.easeInOut(duration: shakeDuration)) {
                shakeOffset = -shakeDistance * 0.5
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + shakeDuration * 4) {
            withAnimation(.easeInOut(duration: shakeDuration)) {
                shakeOffset = 0
            }
        }
    }
}

// MARK: - Selection Button

/// Standard button style for flashcard selection options
struct FlashcardSelectionButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
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

/// Shows progress indicator for current card
/// - Wanikani mode: 8 dots with stage name
/// - Sequential mode: progress bar with position
struct StageIndicatorView: View {
    let mode: StageIndicatorMode

    enum StageIndicatorMode {
        case wanikani(stage: SRSStage, isCapped: Bool)
        case sequential(current: Int, total: Int)
    }

    /// The stage at which partial testing caps advancement
    private static let cappedStage: SRSStage = .familiar2

    var body: some View {
        VStack(spacing: 4) {
            switch mode {
            case .wanikani(let stage, let isCapped):
                wanikaniIndicator(stage: stage, isCapped: isCapped)
            case .sequential(let current, let total):
                sequentialIndicator(current: current, total: total)
            }
        }
    }

    // MARK: - Wanikani Indicator

    private func wanikaniIndicator(stage: SRSStage, isCapped: Bool) -> some View {
        VStack(spacing: 2) {
            // 8 dots (Learning 1 through Mastered)
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

            // Stage name with capped indicator
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

    // MARK: - Sequential Indicator

    private func sequentialIndicator(current: Int, total: Int) -> some View {
        VStack(spacing: 2) {
            // Progress bar with position marker
            GeometryReader { geometry in
                let width = geometry.size.width
                let progress = total > 1 ? CGFloat(current - 1) / CGFloat(total - 1) : 0.5
                let markerX = width * progress

                ZStack(alignment: .leading) {
                    // Track
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 2)

                    // Filled portion
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: markerX, height: 2)

                    // Position marker
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 8, height: 8)
                        .offset(x: markerX - 4)
                }
            }
            .frame(width: 80, height: 8)

            // Position text
            Text("\(current) / \(total)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("Stage Indicators") {
    VStack(spacing: 30) {
        // Wanikani indicators - not capped
        Text("Full Testing").font(.caption).foregroundColor(.secondary)
        ForEach([SRSStage.new, .learning1, .apprentice1, .familiar1, .confident, .mastered], id: \.rawValue) { stage in
            StageIndicatorView(mode: .wanikani(stage: stage, isCapped: false))
        }

        Divider()

        // Wanikani indicators - capped
        Text("Partial Testing (Capped)").font(.caption).foregroundColor(.secondary)
        ForEach([SRSStage.learning1, .familiar1, .familiar2], id: \.rawValue) { stage in
            StageIndicatorView(mode: .wanikani(stage: stage, isCapped: true))
        }

        Divider()

        // Sequential indicators
        Text("Sequential Mode").font(.caption).foregroundColor(.secondary)
        StageIndicatorView(mode: .sequential(current: 1, total: 44))
        StageIndicatorView(mode: .sequential(current: 12, total: 44))
        StageIndicatorView(mode: .sequential(current: 44, total: 44))
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
        VStack(spacing: 6) {
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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

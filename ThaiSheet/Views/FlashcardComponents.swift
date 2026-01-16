//
//  FlashcardComponents.swift
//  ThaiSheet
//
//  Shared components for flashcard views
//

import SwiftUI

// MARK: - Navigable Tap Area

/// A container that detects left/right taps for card navigation
struct NavigableTapArea<Content: View>: View {
    let onPrevious: () -> Void
    let onNext: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    let midPoint = geometry.size.width / 2
                    if location.x < midPoint {
                        onPrevious()
                    } else {
                        onNext()
                    }
                }
        }
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

// MARK: - Progress Indicator

struct FlashcardProgressIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        Text("\(current) / \(total)")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 8)
    }
}

// MARK: - Summary Header

/// Header for the summary section with optional Reveal button
struct FlashcardSummaryHeader: View {
    let showReveal: Bool
    let onReveal: () -> Void

    var body: some View {
        HStack {
            Text("Summary")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

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

// MARK: - Status Ring

/// Circle indicator showing completion status (green for correct, red for errors)
struct FlashcardStatusRing: View {
    let hasError: Bool
    var size: CGFloat = 160
    var lineWidth: CGFloat = 4

    var body: some View {
        Circle()
            .stroke(hasError ? Color.red : Color.green, lineWidth: lineWidth)
            .frame(width: size, height: size)
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

// MARK: - Previews

#Preview("Components") {
    VStack(spacing: 20) {
        // Progress
        FlashcardProgressIndicator(current: 5, total: 44)

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

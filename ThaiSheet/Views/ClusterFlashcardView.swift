//
//  ClusterFlashcardView.swift
//  ThaiSheet
//

import SwiftUI

struct ClusterFlashcardView: View {
    let cluster: Cluster
    let allClusters: [Cluster]
    var onViewInReference: ((String) -> Void)?
    var onComplete: ((Bool) -> Void)?
    let onNext: () -> Void
    let onPrevious: () -> Void

    @State private var cardState = ClusterCardState()
    @State private var soundOptions: [String] = []

    private let typeOptions: [ClusterType] = [.smooth, .silent, .irregular]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Cluster display with status indicator
                clusterCard

                // Summary section
                summarySection

                // Selection area
                selectionArea
            }
            .padding()
        }
        .onAppear {
            generateSoundOptions()
        }
        .onChange(of: cluster.id) { _, _ in
            cardState = ClusterCardState()
            generateSoundOptions()
        }
    }

    // MARK: - Cluster Card

    private var clusterCard: some View {
        FlashcardResultCard(
            showResult: cardState.step == .completed,
            hasError: cardState.hasError(for: cluster)
        ) {
            VStack(spacing: 12) {
                // Main cluster display with swipe gestures
                NavigableTapArea(
                    onPrevious: handlePrevious,
                    onNext: handleNext,
                    onReveal: cardState.step != .completed ? { completeCardEarly() } : nil
                ) {
                    Text(cluster.displayWithVowel)
                        .font(.system(size: 72))
                        .minimumScaleFactor(0.5)
                }
                .frame(height: 140)

                // Action buttons
                HStack(spacing: 20) {
                    Button {
                        onViewInReference?(cluster.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "book")
                            Text("Reference")
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                    }

                    if cardState.step == .completed {
                        let hasSound = AudioPlayer.shared.hasClusterSound(for: cluster.displayWithVowel)
                        Button {
                            AudioPlayer.shared.playClusterSound(for: cluster.displayWithVowel)
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

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlashcardSummaryHeader(
                showReveal: cardState.step != .completed,
                onReveal: { completeCardEarly() }
            )

            VStack(spacing: 6) {
                FlashcardSummaryRow(
                    label: "Type",
                    selectedValue: cardState.selectedType?.displayName,
                    correctValue: cluster.type.displayName,
                    showResult: cardState.step == .completed
                )
                FlashcardSummaryRow(
                    label: "Sound",
                    selectedValue: cardState.selectedSound,
                    correctValue: cluster.sound ?? "(silent)",
                    showResult: cardState.step == .completed
                )

                // Show note when completed
                if cardState.step == .completed, let note = cluster.note {
                    Divider()
                        .padding(.vertical, 4)
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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
        case .selectType:
            typeSelectionView
        case .selectSound:
            soundSelectionView
        case .completed:
            nextCardButton
        }
    }

    private var typeSelectionView: some View {
        VStack(spacing: 16) {
            Text("Select the cluster type")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(typeOptions, id: \.self) { type in
                    FlashcardSelectionButton(label: type.displayName) {
                        cardState.selectedType = type
                        cardState.step = .selectSound
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var soundSelectionView: some View {
        VStack(spacing: 16) {
            Text("Select the sound")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(soundOptions, id: \.self) { sound in
                    FlashcardSelectionButton(label: sound) {
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

    // MARK: - Card Completion

    private func completeCard() {
        cardState.step = .completed
        let wasCorrect = !cardState.hasError(for: cluster)
        onComplete?(wasCorrect)
        if AudioPlayer.shared.hasClusterSound(for: cluster.displayWithVowel) {
            AudioPlayer.shared.playClusterSound(for: cluster.displayWithVowel)
        }
    }

    private func completeCardEarly() {
        cardState.step = .completed
        onComplete?(false)
        if AudioPlayer.shared.hasClusterSound(for: cluster.displayWithVowel) {
            AudioPlayer.shared.playClusterSound(for: cluster.displayWithVowel)
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
        cardState = ClusterCardState()
        onNext()
    }

    private func handlePrevious() {
        cardState = ClusterCardState()
        onPrevious()
    }

    // MARK: - Option Generation

    private func generateSoundOptions() {
        let correctSound = cluster.sound ?? "(silent)"
        let allSounds = Set(allClusters.compactMap { $0.sound })
        var options = Array(allSounds.filter { $0 != cluster.sound }.shuffled().prefix(5))
        options.append(correctSound)
        soundOptions = options.shuffled()
    }
}

// MARK: - Card State

struct ClusterCardState {
    enum Step {
        case selectType
        case selectSound
        case completed
    }

    var step: Step = .selectType
    var selectedType: ClusterType? = nil
    var selectedSound: String? = nil
}

extension ClusterCardState {
    func hasError(for cluster: Cluster) -> Bool {
        if let selected = selectedType, selected != cluster.type {
            return true
        }
        let correctSound = cluster.sound ?? "(silent)"
        if let selected = selectedSound, selected != correctSound {
            return true
        }
        return false
    }
}

#Preview {
    let clusters = Cluster.loadAll()
    return NavigationStack {
        if let first = clusters.first {
            ClusterFlashcardView(
                cluster: first,
                allClusters: clusters,
                onViewInReference: { _ in },
                onNext: {},
                onPrevious: {}
            )
        } else {
            Text("No cluster data")
        }
    }
}

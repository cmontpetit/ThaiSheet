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

    @Environment(\.audioPlayer) private var audioPlayer
    @State private var cardState = ClusterCardState()
    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 72
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
            .contentColumn()
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
        FlashcardFace(
            showResult: cardState.step == .completed,
            hasError: cardState.hasError(for: cluster),
            soundType: .cluster,
            soundKey: cluster.displayWithVowel,
            displayHeight: 140,
            onViewInReference: { onViewInReference?(cluster.id) },
            onPrevious: handlePrevious,
            onNext: handleNext
        ) {
            Text(cluster.displayWithVowel)
                .font(.system(size: glyphSize))
                .minimumScaleFactor(0.5)
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlashcardSummaryHeader(
                showReveal: cardState.step != .completed,
                onReveal: { completeCardEarly() }
            )

            FlashcardSummaryGrid {
                FlashcardSummaryRow(
                    label: "Type",
                    selectedValue: cardState.selectedType?.displayName,
                    correctValue: cluster.type.displayName,
                    showResult: cardState.step == .completed
                )
                FlashcardSummaryRow(
                    label: "Sound",
                    selectedValue: cardState.selectedSound,
                    correctValue: cluster.soundLabel,
                    showResult: cardState.step == .completed
                )

                // Show note when completed
                if cardState.step == .completed, let note = cluster.note {
                    Divider()
                        .padding(.vertical, 4)
                    Text(note.localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
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
        FlashcardStepSection(title: "Select the cluster type") {
            HStack(spacing: 12) {
                ForEach(typeOptions, id: \.self) { type in
                    FlashcardSelectionButton(label: type.displayName) {
                        cardState.selectedType = type
                        cardState.step = .selectSound
                    }
                }
            }
        }
    }

    private var soundSelectionView: some View {
        FlashcardStepSection(title: "Select the sound") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(soundOptions, id: \.self) { sound in
                    FlashcardSelectionButton(label: sound) {
                        cardState.selectedSound = sound
                        completeCard()
                    }
                }
            }
        }
    }

    // MARK: - Card Completion

    private func completeCard(revealed: Bool = false) {
        cardState.step = .completed
        // Revealed early counts as incorrect; otherwise correct if no errors were made
        onComplete?(revealed ? false : !cardState.hasError(for: cluster))
        if audioPlayer.hasSound(.cluster, key: cluster.displayWithVowel) {
            audioPlayer.play(.cluster, key: cluster.displayWithVowel)
        }
    }

    private func completeCardEarly() {
        completeCard(revealed: true)
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
        soundOptions = QuizOptions.pick(
            correct: cluster.soundLabel,
            from: allClusters.compactMap { $0.sound },
            wrongCount: 5
        )
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
        let correctSound = cluster.soundLabel
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

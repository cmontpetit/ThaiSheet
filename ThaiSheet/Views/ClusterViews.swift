//
//  ClusterViews.swift
//  ThaiSheet
//

import SwiftUI

// MARK: - Matrix View for Smooth Clusters

struct ClusterMatrixView: View {
    let clusters: [Cluster]
    var highlightedClusterId: String?
    var onPractice: ((String) -> Void)?

    // Column headers (blend consonants)
    private let blendColumns = ["ร", "ล", "ว"]

    // Row consonants for smooth clusters (derived from data)
    private var rowConsonants: [String] {
        let consonants = Set(clusters.filter { $0.type == .smooth }.map { $0.firstConsonant })
        // Order by Thai alphabet roughly
        let order = ["ก", "ข", "ค", "ต", "ป", "ผ", "พ", "บ", "ด"]
        return order.filter { consonants.contains($0) }
    }

    private func cluster(for consonant: String, blend: String) -> Cluster? {
        clusters.first { $0.firstConsonant == consonant && $0.blendConsonant == blend && $0.type == .smooth }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            ClusterSectionHeaderView(type: .smooth)

            // Matrix
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Text("")
                        .frame(width: 44)
                    ForEach(blendColumns, id: \.self) { blend in
                        Text("-\(blend)-")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.systemGray5))

                Divider()

                // Data rows
                ForEach(rowConsonants, id: \.self) { consonant in
                    HStack(spacing: 0) {
                        // Row header (consonant)
                        Text(consonant)
                            .font(.title3)
                            .frame(width: 44)

                        // Cells for each blend
                        ForEach(blendColumns, id: \.self) { blend in
                            let cellCluster = cluster(for: consonant, blend: blend)
                            ClusterMatrixCell(
                                cluster: cellCluster,
                                isHighlighted: cellCluster?.id == highlightedClusterId,
                                onPractice: onPractice
                            )
                            .frame(maxWidth: .infinity)
                            .id(cellCluster?.id)
                        }
                    }
                    .padding(.vertical, 6)

                    Divider()
                }
            }
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ClusterMatrixCell: View {
    let cluster: Cluster?
    var isHighlighted: Bool = false
    var onPractice: ((String) -> Void)?
    @State private var showingSheet = false

    var body: some View {
        if let cluster = cluster {
            Button {
                showingSheet = true
            } label: {
                VStack(spacing: 2) {
                    Text(cluster.displayWithVowel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let sound = cluster.sound {
                        Text(sound)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundColor(cluster.usageLabel != nil ? .secondary : .primary)
                .padding(4)
                .background(isHighlighted ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingSheet) {
                ClusterDetailSheet(cluster: cluster, onPractice: onPractice)
            }
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
    }
}

// MARK: - Cluster Grid Section (silent and irregular clusters)

struct ClusterGridSection: View {
    let type: ClusterType
    let clusters: [Cluster]
    var highlightedClusterId: String?
    var onPractice: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            ClusterSectionHeaderView(type: type)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(clusters.filter { $0.type == type }) { cluster in
                    ClusterCompactCell(
                        cluster: cluster,
                        isHighlighted: cluster.id == highlightedClusterId,
                        onPractice: onPractice
                    )
                    .id(cluster.id)
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Compact Cell (for grids)

struct ClusterCompactCell: View {
    let cluster: Cluster
    var isHighlighted: Bool = false
    var onPractice: ((String) -> Void)?
    @State private var showingSheet = false

    var body: some View {
        Button {
            showingSheet = true
        } label: {
            VStack(spacing: 2) {
                Text(cluster.displayWithVowel)
                    .font(.title3)
                if let sound = cluster.sound {
                    Text(sound)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isHighlighted ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHighlighted ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSheet) {
            ClusterDetailSheet(cluster: cluster, onPractice: onPractice)
        }
    }
}

// MARK: - Detail Sheet

struct ClusterDetailSheet: View {
    let cluster: Cluster
    var onPractice: ((String) -> Void)?
    @Environment(\.audioPlayer) private var audioPlayer
    @Environment(\.learningModel) var learningModel
    @Environment(\.dismiss) var dismiss

    private var hasSound: Bool {
        audioPlayer.hasSound(.cluster, key: cluster.displayWithVowel)
    }

    private var stage: SRSStage {
        let cardId = "cluster-\(cluster.id)"
        return learningModel.getProgress(forId: cardId).srsStage
    }

    // Build note text combining usage, type description, and note
    private var combinedNote: String? {
        var parts: [String] = []

        if let usage = cluster.usageLabel {
            parts.append(String(localized: "Usage: \(usage)", bundle: .appLanguage))
        }

        parts.append(cluster.type.description)

        if let note = cluster.note {
            parts.append(note)
        }

        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }

    var body: some View {
        ReferenceItemSheet(
            title: cluster.displayWithVowel,
            stage: stage,
            note: combinedNote,
            hasSound: hasSound,
            onPlaySound: {
                audioPlayer.play(.cluster, key: cluster.displayWithVowel)
            },
            onPractice: {
                dismiss()
                onPractice?(cluster.id)
            }
        )
    }
}

// MARK: - Section Header

struct ClusterSectionHeaderView: View {
    let type: ClusterType

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(type.displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(type.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ClusterMatrixView(clusters: Cluster.loadAll())
            ClusterGridSection(type: .silent, clusters: Cluster.loadAll())
            ClusterGridSection(type: .irregular, clusters: Cluster.loadAll())
        }
        .padding(.horizontal)
    }
    .background(Color(.secondarySystemBackground))
}

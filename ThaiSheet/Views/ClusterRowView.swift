//
//  ClusterRowView.swift
//  ThaiSheet
//

import SwiftUI

// MARK: - Matrix View for Smooth Clusters

struct ClusterMatrixView: View {
    let clusters: [Cluster]

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
                            ClusterMatrixCell(cluster: cluster(for: consonant, blend: blend))
                                .frame(maxWidth: .infinity)
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
    @State private var showingSheet = false

    var body: some View {
        if let cluster = cluster {
            Button {
                showingSheet = true
            } label: {
                VStack(spacing: 2) {
                    Text(cluster.cluster)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let sound = cluster.sound {
                        Text(sound)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundColor(cluster.usageLabel != nil ? .secondary : .primary)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingSheet) {
                ClusterDetailSheet(cluster: cluster)
            }
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
    }
}

// MARK: - Silent ห Clusters (Compact Row)

struct SilentClustersView: View {
    let clusters: [Cluster]

    private var silentClusters: [Cluster] {
        clusters.filter { $0.type == .silent }
    }

    var body: some View {
        VStack(spacing: 0) {
            ClusterSectionHeaderView(type: .silent)

            // Compact grid of silent clusters
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(silentClusters) { cluster in
                    ClusterCompactCell(cluster: cluster)
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Irregular Clusters

struct IrregularClustersView: View {
    let clusters: [Cluster]

    private var irregularClusters: [Cluster] {
        clusters.filter { $0.type == .irregular }
    }

    var body: some View {
        VStack(spacing: 0) {
            ClusterSectionHeaderView(type: .irregular)

            VStack(spacing: 0) {
                ForEach(irregularClusters) { cluster in
                    ClusterDetailRow(cluster: cluster)
                    Divider()
                }
            }
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Compact Cell (for grids)

struct ClusterCompactCell: View {
    let cluster: Cluster
    @State private var showingSheet = false

    var body: some View {
        Button {
            showingSheet = true
        } label: {
            VStack(spacing: 2) {
                Text(cluster.cluster)
                    .font(.title3)
                if let sound = cluster.sound {
                    Text(sound)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSheet) {
            ClusterDetailSheet(cluster: cluster)
        }
    }
}

// MARK: - Detail Row (for irregular with notes)

struct ClusterDetailRow: View {
    let cluster: Cluster
    @State private var showingSheet = false

    var body: some View {
        Button {
            showingSheet = true
        } label: {
            HStack(spacing: 12) {
                Text(cluster.cluster)
                    .font(.title2)
                    .frame(width: 50, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    if let sound = cluster.sound {
                        Text("→ \(sound)")
                            .font(.subheadline)
                    }
                    if let usage = cluster.usageLabel {
                        Text(usage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if cluster.note != nil {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSheet) {
            ClusterDetailSheet(cluster: cluster)
        }
    }
}

// MARK: - Detail Sheet

struct ClusterDetailSheet: View {
    let cluster: Cluster
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Cluster display
            Text(cluster.cluster)
                .font(.system(size: 56))
                .padding(.top, 20)

            // Sound
            if let sound = cluster.sound {
                Text(sound)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            // Usage badge
            if let usage = cluster.usageLabel {
                Text(usage.uppercased())
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }

            // Type description
            Text(cluster.type.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Note
            if let note = cluster.note {
                Text(note)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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

// MARK: - Legacy support (keep for compatibility)

struct ClusterRowView: View {
    let cluster: Cluster

    var body: some View {
        ClusterDetailRow(cluster: cluster)
    }
}

struct ClusterSectionView: View {
    let type: ClusterType
    let clusters: [Cluster]

    var body: some View {
        VStack(spacing: 0) {
            ClusterSectionHeaderView(type: type)
            Divider()
            ForEach(clusters) { cluster in
                ClusterRowView(cluster: cluster)
                Divider()
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ClusterMatrixView(clusters: Cluster.loadAll())
            SilentClustersView(clusters: Cluster.loadAll())
            IrregularClustersView(clusters: Cluster.loadAll())
        }
        .padding(.horizontal)
    }
    .background(Color(.secondarySystemBackground))
}

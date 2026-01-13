//
//  ClusterRowView.swift
//  Aksorn
//

import SwiftUI

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

struct ClusterRowView: View {
    let cluster: Cluster

    var body: some View {
        HStack(spacing: 16) {
            Text(cluster.cluster)
                .font(.title2)
                .frame(width: 60, alignment: .leading)

            if let sound = cluster.sound {
                Text(sound)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("(silent)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
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

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ClusterSectionView(
                type: .smooth,
                clusters: [
                    Cluster(cluster: "กร-", sound: "gr-", type: .smooth),
                    Cluster(cluster: "กล-", sound: "gl-", type: .smooth),
                    Cluster(cluster: "กว-", sound: "gw-", type: .smooth)
                ]
            )
            ClusterSectionView(
                type: .silent,
                clusters: [
                    Cluster(cluster: "หง-", sound: nil, type: .silent),
                    Cluster(cluster: "หน-", sound: nil, type: .silent)
                ]
            )
        }
        .padding(.horizontal)
    }
    .background(Color(.secondarySystemBackground))
}

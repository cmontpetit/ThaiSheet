//
//  Cluster.swift
//  ThaiSheet
//

import Foundation

enum ClusterType: String, Codable, CaseIterable {
    case smooth
    case irregular
    case silent

    var displayName: String {
        switch self {
        case .smooth: return "Smooth Clusters"
        case .irregular: return "Irregular Clusters"
        case .silent: return "Silent ห Combinations"
        }
    }

    var description: String {
        switch self {
        case .smooth: return "Standard consonant + r/l/w"
        case .irregular: return "Special pronunciation rules"
        case .silent: return "ห makes syllable high-class"
        }
    }
}

enum ClusterUsage: String, Codable {
    case common
    case uncommon
    case rare
    case ancient
}

struct Cluster: Codable, Identifiable {
    let cluster: String
    let sound: String?
    let type: ClusterType
    let usage: ClusterUsage?
    let note: String?

    var id: String { cluster }

    /// The first consonant of the cluster (e.g., "ก" from "กร-")
    var firstConsonant: String {
        guard let first = cluster.first else { return "" }
        return String(first)
    }

    /// The blend consonant (e.g., "ร" from "กร-")
    var blendConsonant: String {
        guard cluster.count >= 2 else { return "" }
        return String(cluster[cluster.index(after: cluster.startIndex)])
    }

    var usageLabel: String? {
        switch usage {
        case .uncommon: return "uncommon"
        case .rare: return "rare"
        case .ancient: return "ancient"
        case .common, .none: return nil
        }
    }
}

struct ClustersData: Codable {
    let clusters: [Cluster]
}

extension Cluster {
    static func loadAll() -> [Cluster] {
        guard let url = Bundle.main.url(forResource: "clusters", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ClustersData.self, from: data) else {
            return []
        }
        return decoded.clusters
    }

    static func grouped(_ clusters: [Cluster]) -> [(type: ClusterType, clusters: [Cluster])] {
        ClusterType.allCases.compactMap { type in
            let filtered = clusters.filter { $0.type == type }
            return filtered.isEmpty ? nil : (type, filtered)
        }
    }
}

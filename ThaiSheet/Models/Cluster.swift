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
        case .smooth: return String(localized: "Smooth Clusters")
        case .irregular: return String(localized: "Irregular Clusters")
        case .silent: return String(localized: "Silent ห Combinations")
        }
    }

    var chipLabel: String {
        switch self {
        case .smooth: return String(localized: "Smooth")
        case .irregular: return String(localized: "Irregular")
        case .silent: return String(localized: "Silent ห")
        }
    }

    var description: String {
        switch self {
        case .smooth: return String(localized: "Standard consonant + r/l/w")
        case .irregular: return String(localized: "Special pronunciation rules")
        case .silent: return String(localized: "ห makes syllable high-class")
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

    /// Display form with า vowel for pronunciation (e.g., "กร-" → "กรา")
    var displayWithVowel: String {
        let base = cluster.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return base + "า"
    }
}

struct ClustersData: Codable {
    let clusters: [Cluster]
}

extension Cluster {
    static func loadAll() -> [Cluster] {
        BundleLoader.load("clusters", as: ClustersData.self, keyPath: \.clusters)
    }

    static func grouped(_ clusters: [Cluster]) -> [(type: ClusterType, clusters: [Cluster])] {
        ClusterType.allCases.compactMap { type in
            let filtered = clusters.filter { $0.type == type }
            return filtered.isEmpty ? nil : (type, filtered)
        }
    }
}

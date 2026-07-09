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
        case .smooth: return String(localized: "Smooth Clusters", bundle: .appLanguage)
        case .irregular: return String(localized: "Irregular Clusters", bundle: .appLanguage)
        case .silent: return String(localized: "Silent ห Combinations", bundle: .appLanguage)
        }
    }

    var chipLabel: String {
        switch self {
        case .smooth: return String(localized: "Smooth", bundle: .appLanguage)
        case .irregular: return String(localized: "Irregular", bundle: .appLanguage)
        case .silent: return String(localized: "Silent ห", bundle: .appLanguage)
        }
    }

    var description: String {
        switch self {
        case .smooth: return String(localized: "Standard consonant + r/l/w", bundle: .appLanguage)
        case .irregular: return String(localized: "Special pronunciation rules", bundle: .appLanguage)
        case .silent: return String(localized: "ห makes syllable high-class", bundle: .appLanguage)
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
        case .uncommon: return String(localized: "uncommon", bundle: .appLanguage)
        case .rare: return String(localized: "rare", bundle: .appLanguage)
        case .ancient: return String(localized: "ancient", bundle: .appLanguage)
        case .common, .none: return nil
        }
    }

    /// Sound for display and quiz options; silent clusters get a localized marker
    var soundLabel: String {
        sound ?? String(localized: "(silent)", bundle: .appLanguage)
    }

    /// Display form with า vowel for pronunciation (e.g., "กร-" → "กรา").
    /// Final-position clusters (leading "-", e.g. "-ทร") display as written.
    var displayWithVowel: String {
        guard !cluster.hasPrefix("-") else { return cluster }
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

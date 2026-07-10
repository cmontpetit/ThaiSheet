//
//  BundleLoader.swift
//  ThaiSheet
//

import Foundation
import os

enum BundleLoader {
    private static let logger = Logger(subsystem: "net.montpetit.thaisheet", category: "BundleLoader")

    /// Load a JSON resource from the app bundle, extracting an array via a key path.
    /// Returns [] on a missing or malformed resource (a packaging bug), logging the
    /// cause; the graceful-empty contract is pinned by BundleLoaderTests.
    static func load<Container: Decodable, Item>(
        _ resource: String,
        as type: Container.Type,
        keyPath: KeyPath<Container, [Item]>
    ) -> [Item] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
            logger.error("Bundled resource \(resource, privacy: .public).json not found")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(type, from: data)[keyPath: keyPath]
        } catch {
            logger.error("Failed to decode \(resource, privacy: .public).json: \(error, privacy: .public)")
            return []
        }
    }
}

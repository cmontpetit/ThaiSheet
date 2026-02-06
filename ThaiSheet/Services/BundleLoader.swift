//
//  BundleLoader.swift
//  ThaiSheet
//

import Foundation

enum BundleLoader {
    /// Load a JSON resource from the app bundle, extracting an array via a key path.
    static func load<Container: Decodable, Item>(
        _ resource: String,
        as type: Container.Type,
        keyPath: KeyPath<Container, [Item]>
    ) -> [Item] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(type, from: data) else {
            return []
        }
        return decoded[keyPath: keyPath]
    }
}

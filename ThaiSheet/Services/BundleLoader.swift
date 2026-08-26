//
//  BundleLoader.swift
//  ThaiSheet
//

import Foundation
import os

/// Why a bundled dataset could not be produced. Each case is detected at the
/// point it happens rather than inferred later from an empty array, so the
/// difference between "not in the bundle", "could not be read", "did not
/// decode", and "decoded to nothing" survives to the UI and the logs.
enum DatasetLoadFailure: Equatable {
    /// No such resource in the app bundle (a packaging bug).
    case resourceMissing
    /// The resource exists but its bytes could not be read.
    case readFailed(diagnostic: String)
    /// The bytes were read but did not decode into the expected shape.
    case decodeFailed(diagnostic: String)
    /// Decoding succeeded and produced no rows, which for a bundled catalog is
    /// a packaging bug rather than a legitimately empty dataset.
    case decodedEmpty
}

/// A dataset that failed to load, named by its bundled resource.
///
/// `diagnostic` text comes from `Error.localizedDescription` on file and
/// decoding errors — bundle contents and coding paths, never user data — so it
/// is safe to log and to keep in memory.
struct DatasetLoadError: Error, Equatable {
    let resource: String
    let failure: DatasetLoadFailure
}

/// Supplies the raw bytes of a bundled JSON resource. Injecting this is what
/// lets tests drive every failure path through `ThaiDataStore` without shipping
/// a broken bundle.
protocol ResourceProviding {
    func data(forResource resource: String) throws -> Data
}

/// The real provider: reads `<resource>.json` from the app bundle.
struct BundleResourceProvider: ResourceProviding {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func data(forResource resource: String) throws -> Data {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw DatasetLoadError(resource: resource, failure: .resourceMissing)
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw DatasetLoadError(
                resource: resource,
                failure: .readFailed(diagnostic: error.localizedDescription)
            )
        }
    }
}

enum BundleLoader {
    private static let logger = Logger(subsystem: "net.montpetit.thaisheet", category: "BundleLoader")

    /// Load a JSON resource and extract an array via a key path.
    ///
    /// Returns the rows, or the specific reason they could not be produced.
    /// Callers that only want the rows can use `items(of:)`; `ThaiDataStore`
    /// keeps the failures so the UI can say what is unavailable.
    static func load<Container: Decodable, Item>(
        _ resource: String,
        as type: Container.Type,
        keyPath: KeyPath<Container, [Item]>,
        provider: ResourceProviding = BundleResourceProvider()
    ) -> Result<[Item], DatasetLoadError> {
        let data: Data
        do {
            data = try provider.data(forResource: resource)
        } catch let error as DatasetLoadError {
            return .failure(logged(error))
        } catch {
            return .failure(logged(DatasetLoadError(
                resource: resource,
                failure: .readFailed(diagnostic: error.localizedDescription)
            )))
        }

        let items: [Item]
        do {
            items = try JSONDecoder().decode(type, from: data)[keyPath: keyPath]
        } catch {
            return .failure(logged(DatasetLoadError(
                resource: resource,
                failure: .decodeFailed(diagnostic: error.localizedDescription)
            )))
        }

        guard !items.isEmpty else {
            return .failure(logged(DatasetLoadError(resource: resource, failure: .decodedEmpty)))
        }
        return .success(items)
    }

    /// The rows alone, empty when the dataset failed. For call sites that have
    /// no failure state to show; anything user-facing should use `load`.
    static func items<Container: Decodable, Item>(
        _ resource: String,
        as type: Container.Type,
        keyPath: KeyPath<Container, [Item]>,
        provider: ResourceProviding = BundleResourceProvider()
    ) -> [Item] {
        (try? load(resource, as: type, keyPath: keyPath, provider: provider).get()) ?? []
    }

    private static func logged(_ error: DatasetLoadError) -> DatasetLoadError {
        switch error.failure {
        case .resourceMissing:
            logger.error("Bundled resource \(error.resource, privacy: .public).json not found")
        case .readFailed(let diagnostic):
            logger.error("Failed to read \(error.resource, privacy: .public).json: \(diagnostic, privacy: .public)")
        case .decodeFailed(let diagnostic):
            logger.error("Failed to decode \(error.resource, privacy: .public).json: \(diagnostic, privacy: .public)")
        case .decodedEmpty:
            logger.error("Bundled resource \(error.resource, privacy: .public).json decoded to zero rows")
        }
        return error
    }
}

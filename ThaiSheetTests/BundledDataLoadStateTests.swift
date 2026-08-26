//
//  BundledDataLoadStateTests.swift
//  ThaiSheetTests
//
//  Bundled-data failure handling (#28): every failure kind is detected where it
//  happens, and a failed catalog degrades one section rather than the app.
//

import XCTest
@testable import ThaiSheet

/// Serves bundled resources, with per-resource failures injected. Real bundle
/// bytes are used for everything not overridden, so a "partial catalog" test
/// exercises genuine data alongside one broken dataset.
private struct StubResourceProvider: ResourceProviding {
    enum Outcome {
        case realBundle
        case missing
        case unreadable
        case malformed
        case emptyCatalog(key: String)
    }

    var outcomes: [String: Outcome] = [:]

    func data(forResource resource: String) throws -> Data {
        switch outcomes[resource] ?? .realBundle {
        case .realBundle:
            return try BundleResourceProvider().data(forResource: resource)
        case .missing:
            throw DatasetLoadError(resource: resource, failure: .resourceMissing)
        case .unreadable:
            throw DatasetLoadError(
                resource: resource,
                failure: .readFailed(diagnostic: "stubbed read failure")
            )
        case .malformed:
            return Data("{ this is not json".utf8)
        case .emptyCatalog(let key):
            return Data("{\"\(key)\": []}".utf8)
        }
    }
}

private struct ConsonantsShape: Decodable {
    let consonants: [Consonant]
}

final class BundledDataLoadStateTests: XCTestCase {

    // MARK: - Loader distinguishes failure kinds

    func test_load_missingResource_reportsResourceMissing() {
        let provider = StubResourceProvider(outcomes: ["consonants": .missing])
        let result = BundleLoader.load(
            "consonants", as: ConsonantsShape.self, keyPath: \.consonants, provider: provider
        )

        XCTAssertEqual(result.loadError, DatasetLoadError(resource: "consonants", failure: .resourceMissing))
    }

    func test_load_unreadableResource_reportsReadFailure() {
        let provider = StubResourceProvider(outcomes: ["consonants": .unreadable])
        let result = BundleLoader.load(
            "consonants", as: ConsonantsShape.self, keyPath: \.consonants, provider: provider
        )

        guard case .readFailed(let diagnostic)? = result.loadError?.failure else {
            return XCTFail("Expected a read failure, got \(String(describing: result.loadError))")
        }
        XCTAssertEqual(diagnostic, "stubbed read failure",
                       "The underlying diagnostic must survive to the caller")
    }

    func test_load_malformedJSON_reportsDecodeFailure() {
        let provider = StubResourceProvider(outcomes: ["consonants": .malformed])
        let result = BundleLoader.load(
            "consonants", as: ConsonantsShape.self, keyPath: \.consonants, provider: provider
        )

        guard case .decodeFailed(let diagnostic)? = result.loadError?.failure else {
            return XCTFail("Expected a decode failure, got \(String(describing: result.loadError))")
        }
        XCTAssertFalse(diagnostic.isEmpty, "Decoding diagnostics must be preserved")
    }

    func test_load_decodedEmptyCatalog_isItsOwnFailure_notInferredFromCount() {
        let provider = StubResourceProvider(outcomes: ["consonants": .emptyCatalog(key: "consonants")])
        let result = BundleLoader.load(
            "consonants", as: ConsonantsShape.self, keyPath: \.consonants, provider: provider
        )

        XCTAssertEqual(result.loadError, DatasetLoadError(resource: "consonants", failure: .decodedEmpty))
    }

    func test_load_realBundle_succeeds() {
        let result = BundleLoader.load(
            "consonants", as: ConsonantsShape.self, keyPath: \.consonants,
            provider: StubResourceProvider()
        )

        XCTAssertNil(result.loadError)
        XCTAssertEqual((try? result.get())?.count, 44)
    }

    // MARK: - ThaiDataStore aggregates per dataset

    func test_store_realBundle_isLoaded() {
        let store = makeRetainedStore(StubResourceProvider())

        XCTAssertEqual(store.loadState, .loaded,
                       "The shipped bundle must load cleanly; a failure here is a packaging regression")
        XCTAssertTrue(store.isLoaded)
        XCTAssertTrue(store.failures.isEmpty)
    }

    func test_store_missingVowels_failsOnlyThatDataset() {
        let store = makeRetainedStore(StubResourceProvider(outcomes: ["vowels": .missing]))

        XCTAssertEqual(store.failures[.vowels]?.failure, .resourceMissing)
        XCTAssertEqual(store.loadState,
                       .failed(errors: [DatasetLoadError(resource: "vowels", failure: .resourceMissing)]))
        XCTAssertFalse(store.isLoaded)
    }

    func test_store_malformedToneRules_keepsOtherCatalogsUsable() {
        let store = makeRetainedStore(StubResourceProvider(outcomes: ["tone-rules": .malformed]))

        // The broken catalog is empty and reported...
        XCTAssertTrue(store.toneRuleCards.isEmpty)
        XCTAssertFalse(store.isAvailable(.toneRules))
        // ...while every other catalog loaded from the real bundle.
        XCTAssertEqual(store.consonants.count, 44)
        XCTAssertFalse(store.vowelCards.isEmpty)
        XCTAssertFalse(store.clusters.isEmpty)
        XCTAssertTrue(store.isAvailable(.consonants))
        XCTAssertTrue(store.isAvailable(.vowels))
        XCTAssertTrue(store.isAvailable(.clusters))
        XCTAssertTrue(store.isAvailable(.toneMarks))
    }

    func test_store_multipleFailures_areOrderedAndNamed() {
        let store = makeRetainedStore(StubResourceProvider(outcomes: [
            "clusters": .missing,
            "consonants": .emptyCatalog(key: "consonants"),
        ]))

        guard case .failed(let errors) = store.loadState else {
            return XCTFail("Expected a failed load state")
        }
        XCTAssertEqual(errors.map(\.resource), ["consonants", "clusters"],
                       "Errors follow ThaiDataset.allCases order so the state is stable to compare")
        XCTAssertEqual(errors.map(\.failure), [.decodedEmpty, .resourceMissing])
    }

    // MARK: - Reference degrades one section at a time

    func test_referenceSections_onlyTheFailedSectionIsUnavailable() {
        let store = makeRetainedStore(StubResourceProvider(outcomes: ["clusters": .missing]))

        XCTAssertFalse(store.isAvailable(CheatsheetEntryType.clusters.requiredDatasets))
        XCTAssertTrue(store.isAvailable(CheatsheetEntryType.consonants.requiredDatasets))
        XCTAssertTrue(store.isAvailable(CheatsheetEntryType.vowels.requiredDatasets))
        XCTAssertTrue(store.isAvailable(CheatsheetEntryType.tones.requiredDatasets))
    }

    func test_tonesSection_needsBothToneCatalogs() {
        let marksBroken = makeRetainedStore(StubResourceProvider(outcomes: ["tone-marks": .missing]))
        let rulesBroken = makeRetainedStore(StubResourceProvider(outcomes: ["tone-rules": .missing]))

        XCTAssertFalse(marksBroken.isAvailable(CheatsheetEntryType.tones.requiredDatasets),
                       "The Tones section shows both tables, so either catalog failing makes it unavailable")
        XCTAssertFalse(rulesBroken.isAvailable(CheatsheetEntryType.tones.requiredDatasets))
        XCTAssertTrue(marksBroken.isAvailable(CheatsheetEntryType.consonants.requiredDatasets))
        XCTAssertTrue(rulesBroken.isAvailable(CheatsheetEntryType.consonants.requiredDatasets))
    }

    // MARK: - Flashcards: failure state vs. empty-filter state

    @MainActor
    func test_flashcards_failedData_isUnavailable_notAnEmptyFilterState() {
        let store = makeRetainedStore(StubResourceProvider(outcomes: ["vowels": .missing]))
        let manager = makeRetainedManager(data: store) { _ in }

        XCTAssertFalse(manager.isLoaded)
        XCTAssertNotEqual(manager.data.loadState, .loaded,
                          "A failed dataset must reach the view as a failure, not as an empty deck")
    }

    @MainActor
    func test_flashcards_loadedDataWithEverythingFilteredOut_staysTheEmptyFilterState() {
        let store = makeRetainedStore(StubResourceProvider())
        let manager = makeRetainedManager(data: store) { settings in
            settings.consonantsEnabled = false
            settings.vowelsEnabled = false
            settings.tonesEnabled = false
            settings.clusters = false
        }

        XCTAssertEqual(manager.data.loadState, .loaded)
        XCTAssertTrue(manager.isLoaded, "Filters emptying the deck is not a load failure")
        XCTAssertTrue(manager.filteredCards.isEmpty, "This is the 'No Cards' state, reached with good data")
    }

    @MainActor
    func test_flashcards_loadedData_hasCards() {
        let store = makeRetainedStore(StubResourceProvider())
        let manager = makeRetainedManager(data: store) { _ in }

        XCTAssertEqual(manager.data.loadState, .loaded)
        XCTAssertFalse(manager.filteredCards.isEmpty)
    }

    // MARK: - Fixtures

    /// Stores, managers, settings and models built here stay alive for the
    /// process: deallocating a short-lived bundle-backed store or @Observable
    /// instance trips the toolchain invalid-free described under Testing
    /// Gotchas in CLAUDE.md.
    private static var retained: [AnyObject] = []

    private func makeRetainedStore(_ provider: StubResourceProvider) -> ThaiDataStore {
        let store = ThaiDataStore(provider: provider)
        BundledDataLoadStateTests.retained.append(store)
        return store
    }

    @MainActor
    private func makeRetainedManager(
        data: ThaiDataStore,
        configure: (FlashcardSettings) -> Void
    ) -> FlashcardManager {
        let store = InMemoryStore()
        let settings = FlashcardSettings(defaults: store)
        configure(settings)
        let learningModel = LearningModel(store: store)
        let manager = FlashcardManager(settings: settings, learningModel: learningModel, data: data)
        BundledDataLoadStateTests.retained.append(contentsOf: [store, settings, learningModel, manager] as [AnyObject])
        return manager
    }
}

private extension Result where Failure == DatasetLoadError {
    var loadError: DatasetLoadError? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}

private final class InMemoryStore: KeyValueStore {
    private var values: [String: Any] = [:]

    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func set(_ value: Bool, forKey key: String) { values[key] = value }
    func object(forKey key: String) -> Any? { values[key] }
    func string(forKey key: String) -> String? { values[key] as? String }
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func removeObject(forKey key: String) { values.removeValue(forKey: key) }

    @discardableResult
    func synchronize() -> Bool { true }
}

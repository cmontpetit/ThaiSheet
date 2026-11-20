//
//  BookChapter.swift
//  ThaiSheet
//

import Foundation
import os

/// A chapter of the book "Read Thai in 10 Days", in reading order.
/// The raw values are persisted (`fc_bookProgress`) and appear in
/// `read-thai-10-days.json`: never rename one.
enum BookChapter: String, CaseIterable, Comparable {
    case day1, day2, day3, day4, day5, day6, day7, day8, day9, lastDay

    static func < (lhs: BookChapter, rhs: BookChapter) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

/// Where the book introduces an item: in a numbered chapter, or nowhere.
enum BookPlacement: Equatable {
    case chapter(BookChapter)
    /// No numbered chapter teaches or shows the item.
    case notInBook

    init?(rawValue: String) {
        if rawValue == "notInBook" {
            self = .notInBook
        } else if let chapter = BookChapter(rawValue: rawValue) {
            self = .chapter(chapter)
        } else {
            return nil
        }
    }
}

/// The bundled `read-thai-10-days.json` mapping: every catalog item to the
/// chapter that introduces it. Keys are the catalog's durable identities.
/// Vowels key on the Reference slot (`row:Duration:Form`), which is not always
/// the card's progress key (a row's `progressKeys` override can differ).
struct BookChapterMap: Equatable {
    let consonants: [String: BookPlacement]
    let vowels: [String: BookPlacement]
    let clusters: [String: BookPlacement]
    let toneRules: [String: BookPlacement]
    let toneMarks: [String: BookPlacement]

    static let resource = "read-thai-10-days"
    private static let logger = Logger(subsystem: "net.montpetit.thaisheet", category: "BookChapterMap")

    // MARK: Lookups (nil = the item has no entry, a data bug the tests catch)

    func placement(of consonant: Consonant) -> BookPlacement? {
        consonants[consonant.id]
    }

    func placement(of vowel: Vowel, duration: VowelCard.VowelDuration, form: VowelCard.VowelFormType) -> BookPlacement? {
        vowels[Self.vowelSlotKey(vowel, duration: duration, form: form)]
    }

    func placement(of cluster: Cluster) -> BookPlacement? {
        clusters[cluster.id]
    }

    func placement(of rule: ToneRule, sample: ToneSample) -> BookPlacement? {
        toneRules[ToneRuleCard.key(rule: rule, sample: sample)]
    }

    func placement(of card: ToneMarkCard) -> BookPlacement? {
        toneMarks[card.id]
    }

    /// A tone mark's class entry; same key as its card (`mark:Class`).
    func placement(of mark: ToneMark, className: String) -> BookPlacement? {
        toneMarks["\(mark.id):\(className)"]
    }

    static func vowelSlotKey(_ vowel: Vowel, duration: VowelCard.VowelDuration, form: VowelCard.VowelFormType) -> String {
        "\(vowel.id):\(duration.rawValue):\(form.rawValue)"
    }

    // MARK: Loading

    static func load(provider: ResourceProviding = BundleResourceProvider()) -> Result<BookChapterMap, DatasetLoadError> {
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
        do {
            return .success(try decode(data))
        } catch {
            return .failure(logged(DatasetLoadError(
                resource: resource,
                failure: .decodeFailed(diagnostic: String(describing: error))
            )))
        }
    }

    private struct File: Decodable {
        let consonants: [String: String]
        let vowels: [String: String]
        let clusters: [String: String]
        let toneRules: [String: String]
        let toneMarks: [String: String]
    }

    struct InvalidPlacement: Error, CustomStringConvertible {
        let key: String
        let value: String
        var description: String { "Invalid chapter \"\(value)\" for \"\(key)\"" }
    }

    static func decode(_ data: Data) throws -> BookChapterMap {
        let file = try JSONDecoder().decode(File.self, from: data)
        func placements(_ raw: [String: String]) throws -> [String: BookPlacement] {
            try raw.reduce(into: [:]) { result, entry in
                guard let placement = BookPlacement(rawValue: entry.value) else {
                    throw InvalidPlacement(key: entry.key, value: entry.value)
                }
                result[entry.key] = placement
            }
        }
        return BookChapterMap(
            consonants: try placements(file.consonants),
            vowels: try placements(file.vowels),
            clusters: try placements(file.clusters),
            toneRules: try placements(file.toneRules),
            toneMarks: try placements(file.toneMarks)
        )
    }

    private static func logged(_ error: DatasetLoadError) -> DatasetLoadError {
        logger.error("Failed to load \(error.resource, privacy: .public).json: \(String(describing: error.failure), privacy: .public)")
        return error
    }
}

/// The learner's book progress applied to the catalog: an item is in scope when
/// the book has introduced it by `upTo`. Items no chapter teaches are in scope
/// only with `includesNotInBook`. A nil `upTo` (scope Off) includes everything.
struct BookScope: Equatable {
    let upTo: BookChapter?
    let includesNotInBook: Bool

    init(upTo: BookChapter?, includesNotInBook: Bool) {
        self.upTo = upTo
        self.includesNotInBook = includesNotInBook
    }

    /// The scope both tabs apply. Without a loaded map there is nothing to
    /// place items by, so the scope is Off whatever the setting says: a failed
    /// load must never hide the catalog. (A missing entry inside a loaded map
    /// is different: it counts as not taught in the book.)
    init(settings: FlashcardSettings, map: BookChapterMap?) {
        self.init(
            upTo: map == nil ? nil : settings.bookProgress,
            includesNotInBook: settings.showNotInBook
        )
    }

    var isActive: Bool { upTo != nil }

    /// A missing entry counts as not in the book.
    func includes(_ placement: BookPlacement?) -> Bool {
        guard let upTo else { return true }
        switch placement {
        case .chapter(let chapter): return chapter <= upTo
        case .notInBook, nil: return includesNotInBook
        }
    }
}

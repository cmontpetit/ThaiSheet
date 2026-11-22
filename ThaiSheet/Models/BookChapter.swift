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

/// Which "Read Thai in 10 Days" material both tabs show (Study Content).
enum BookSelection: Hashable {
    /// No book-day filtering
    case off
    /// Cumulative: everything introduced up to and including the chapter
    case through(BookChapter)
    /// Only what the chosen chapters introduce. Never empty.
    case days(Set<BookChapter>)

    /// Persisted form (`fc_bookSelection`): "off", "through:day4", or
    /// "days:day2,day4" (chapters in book order). The raw chapter values are
    /// persisted: never rename one.
    var storageValue: String {
        switch self {
        case .off:
            return "off"
        case .through(let chapter):
            return "through:\(chapter.rawValue)"
        case .days(let chapters):
            return "days:" + chapters.sorted().map(\.rawValue).joined(separator: ",")
        }
    }

    /// nil for anything unreadable (a value from a newer build, or an empty day list).
    init?(storageValue: String) {
        if storageValue == "off" {
            self = .off
            return
        }
        let parts = storageValue.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "through":
            guard let chapter = BookChapter(rawValue: parts[1]) else { return nil }
            self = .through(chapter)
        case "days":
            let raw = parts[1].split(separator: ",").map(String.init)
            let chapters = raw.compactMap(BookChapter.init(rawValue:))
            guard !chapters.isEmpty, chapters.count == raw.count else { return nil }
            self = .days(Set(chapters))
        default:
            return nil
        }
    }

    /// The cumulative chapter older builds understand (`fc_bookProgress`): the
    /// chapter itself, or the last selected day, which covers every selected day.
    var legacyProgress: BookChapter? {
        switch self {
        case .off: nil
        case .through(let chapter): chapter
        case .days(let chapters): chapters.max()
        }
    }

    var isOff: Bool { self == .off }
}

/// The learner's book selection applied to the catalog: an item is in scope
/// when a selected chapter introduces it (through a chapter: that chapter or
/// an earlier one). Items no chapter teaches are in scope only with
/// `includesNotInBook`. `.off` includes everything.
struct BookScope: Equatable {
    let selection: BookSelection
    let includesNotInBook: Bool

    init(selection: BookSelection, includesNotInBook: Bool) {
        self.selection = selection
        self.includesNotInBook = includesNotInBook
    }

    /// Cumulative scope; nil is Off.
    init(upTo: BookChapter?, includesNotInBook: Bool) {
        self.init(selection: upTo.map { .through($0) } ?? .off, includesNotInBook: includesNotInBook)
    }

    /// The scope both tabs apply. Without a loaded map there is nothing to
    /// place items by, so the scope is Off whatever the setting says: a failed
    /// load must never hide the catalog. (A missing entry inside a loaded map
    /// is different: it counts as not taught in the book.)
    init(settings: FlashcardSettings, map: BookChapterMap?) {
        self.init(
            selection: map == nil ? .off : settings.bookSelection,
            includesNotInBook: settings.showNotInBook
        )
    }

    var isActive: Bool { !selection.isOff }

    /// A missing entry counts as not in the book.
    func includes(_ placement: BookPlacement?) -> Bool {
        switch selection {
        case .off:
            return true
        case .through(let upTo):
            if case .chapter(let chapter) = placement { return chapter <= upTo }
        case .days(let chapters):
            if case .chapter(let chapter) = placement { return chapters.contains(chapter) }
        }
        return includesNotInBook
    }
}

import XCTest
@testable import ThaiSheet

@MainActor
final class QuizOptionCacheTests: XCTestCase {
    func test_reappearingWithSameContextKeepsChoicesAndOrder() {
        let context = QuizOptionContext(cardID: "vowel-test", romanization: .learner)
        var cache = QuizOptionCache(value: [String]())
        var generations = 0
        func generate() -> [String] {
            generations += 1
            return ["choice-\(generations)", "correct"]
        }

        cache.update(for: context, generate: generate)
        let original = cache.value
        // Tab reappearance and layout updates may both request preparation.
        cache.update(for: context, generate: generate)
        cache.update(for: context, generate: generate)

        XCTAssertEqual(cache.value, original)
        XCTAssertEqual(generations, 1)
    }

    func test_changingRomanizationRegeneratesDistinctDisplayedChoices() {
        let previousScheme = RomanizationState.shared.scheme
        defer { RomanizationState.shared.scheme = previousScheme }
        var cache = QuizOptionCache(value: [String]())
        var generations = 0
        for scheme in [RomanizationScheme.learner, .rtgs] {
            RomanizationState.shared.scheme = scheme
            cache.update(for: QuizOptionContext(cardID: "consonant-test", romanization: scheme)) {
                generations += 1
                return QuizOptions.pickDistinct(correct: "j-", from: ["j-", "ch-", "g-", "kh-"], wrongCount: 7)
            }
            XCTAssertTrue(cache.value.contains("j-"))
            XCTAssertEqual(Set(cache.value.map(\.romanized)).count, cache.value.count)
        }
        XCTAssertEqual(generations, 2)
        XCTAssertEqual(cache.value.count, 3, "RTGS merges j- and ch- into one displayed answer")
    }

    func test_cardAndConsonantModeChangesStartNewContexts() {
        var cache = QuizOptionCache(value: 0)
        var generations = 0
        let contexts = [
            FlashcardType.consonantCardId(for: "ก", includesName: true),
            FlashcardType.consonantCardId(for: "ก", includesName: false),
            FlashcardType.consonantCardId(for: "ข", includesName: false),
            FlashcardType.consonantCardId(for: "ก", includesName: true),
        ]
        for cardID in contexts {
            cache.update(for: QuizOptionContext(cardID: cardID, romanization: .learner)) {
                generations += 1
                return generations
            }
            XCTAssertEqual(cache.value, generations)
        }
        XCTAssertEqual(generations, 4)
    }

    func test_switchingToBookNotationRegeneratesClusterChoicesOnTheSameCard() {
        let previousScheme = RomanizationState.shared.scheme
        defer { RomanizationState.shared.scheme = previousScheme }
        let cardID = FlashcardType.cluster.cardId(for: "พล:initial")
        var cache = QuizOptionCache(value: [String]())
        for scheme in [RomanizationScheme.learner, .readThaiIn10Days] {
            RomanizationState.shared.scheme = scheme
            cache.update(for: QuizOptionContext(cardID: cardID, romanization: scheme)) {
                QuizOptions.pickDistinct(correct: "phl-", from: ["phl-", "pl-", "bpl-"], wrongCount: 3)
            }
            XCTAssertEqual(cache.value.contains("pl-"), scheme == .learner)
            XCTAssertTrue(cache.value.contains("phl-"))
        }
    }
}

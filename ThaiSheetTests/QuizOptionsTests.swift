//
//  QuizOptionsTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

final class QuizOptionsTests: XCTestCase {

    func test_pick_containsCorrectAnswer() {
        let options = QuizOptions.pick(correct: "a", from: ["b", "c", "d"], wrongCount: 2)
        XCTAssertTrue(options.contains("a"))
    }

    func test_pick_returnsWrongCountPlusOne() {
        let options = QuizOptions.pick(correct: "a", from: ["b", "c", "d", "e"], wrongCount: 3)
        XCTAssertEqual(options.count, 4)
    }

    func test_pick_correctAppearsExactlyOnce_evenIfInPool() {
        let options = QuizOptions.pick(correct: "a", from: ["a", "b", "c"], wrongCount: 5)
        XCTAssertEqual(options.filter { $0 == "a" }.count, 1)
    }

    func test_pick_deduplicatesWrongAnswers() {
        let options = QuizOptions.pick(correct: "a", from: ["b", "b", "b", "c"], wrongCount: 5)
        XCTAssertEqual(options.sorted(), ["a", "b", "c"])
    }

    func test_pick_smallPool_returnsAllAvailable() {
        let options = QuizOptions.pick(correct: "a", from: ["b"], wrongCount: 7)
        XCTAssertEqual(options.sorted(), ["a", "b"])
    }

    func test_pick_emptyPool_returnsOnlyCorrect() {
        let options = QuizOptions.pick(correct: "a", from: [String](), wrongCount: 7)
        XCTAssertEqual(options, ["a"])
    }
}

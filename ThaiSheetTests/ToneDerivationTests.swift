//
//  ToneDerivationTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

final class ToneDerivationTests: XCTestCase {

    private typealias Input = ToneDerivation.Input
    private typealias Duration = VowelCard.VowelDuration

    private var rules: [ToneRule]!
    private var marks: [ToneMark]!

    override func setUp() {
        super.setUp()
        rules = ToneRule.loadAll()
        marks = ToneMark.loadAll()
    }

    override func tearDown() {
        rules = nil
        marks = nil
        super.tearDown()
    }

    private func derive(
        _ consonantClass: ConsonantClass,
        _ duration: Duration,
        _ ending: ToneDerivation.Ending,
        mark: String? = nil
    ) -> ToneDerivation {
        ToneDerivation.derive(
            Input(consonantClass: consonantClass, vowelDuration: duration, ending: ending, toneMark: mark),
            rules: rules,
            marks: marks
        )
    }

    /// Steps as comparable text (`ToneRule` and `ToneMark` are not Equatable)
    private func trace(_ derivation: ToneDerivation) -> [String] {
        derivation.steps.map { step in
            switch step {
            case .noToneMark: return "no mark"
            case .toneMark(let mark): return "mark \(mark)"
            case .consonantClass(let cls): return "class \(cls.rawValue)"
            case .ending(let ending): return "ending \(ending.rawValue)"
            case .vowelDuration(let duration): return "duration \(duration.rawValue)"
            case .toneRule(let rule): return "rule \(rule.id)"
            case .toneMarkRow(let row, let cls): return "mark row \(row.id) on \(cls.rawValue)"
            }
        }
    }

    // MARK: - Tone rules (unmarked syllables)

    func test_bundledTables_haveTheExpectedShape() {
        XCTAssertEqual(rules.count, 7)
        XCTAssertEqual(marks.count, 4)
    }

    /// Each rule row is expanded into the inputs it describes by reading its
    /// own fields, independently of the derivation's matching code.
    func test_everyToneRule_derivesTheToneItsRowStates() throws {
        var checked = 0
        for rule in rules {
            let cls = try XCTUnwrap(ConsonantClass(rawValue: rule.initialConsonant.lowercased()), rule.id)
            let durations: [Duration]
            switch rule.vowelDuration {
            case "Short": durations = [.short]
            case "Long": durations = [.long]
            case "Any": durations = [.short, .long]
            default: return XCTFail("Unexpected vowelDuration in \(rule.id)")
            }
            let ending: ToneDerivation.Ending
            switch rule.end {
            case "Live": ending = .live
            case "Dead", "Dead/None": ending = .dead
            default: return XCTFail("Unexpected end in \(rule.id)")
            }

            for duration in durations {
                let derivation = derive(cls, duration, ending)
                XCTAssertEqual(derivation.outcome, .tone(rule.tone), rule.id)
                guard case .toneRule(let deciding)? = derivation.decidingStep else {
                    XCTFail("\(rule.id): the deciding step should be the rule row")
                    continue
                }
                XCTAssertEqual(deciding.id, rule.id)
                checked += 1
            }
        }
        // 2 single-duration rules + 5 "Any" rules covering both durations
        XCTAssertEqual(checked, 12)
    }

    /// Pins all 12 unmarked inputs to the cheat sheet's tones, so a change to
    /// the table or to the matching shows up as a readable failure.
    func test_everyUnmarkedInput_isCoveredWithTheCheatSheetTone() {
        let expected: [(ConsonantClass, Duration, ToneDerivation.Ending, String)] = [
            (.low, .short, .live, "Mid"),
            (.low, .long, .live, "Mid"),
            (.low, .short, .dead, "High"),
            (.low, .long, .dead, "Falling"),
            (.mid, .short, .live, "Mid"),
            (.mid, .long, .live, "Mid"),
            (.mid, .short, .dead, "Low"),
            (.mid, .long, .dead, "Low"),
            (.high, .short, .live, "Rising"),
            (.high, .long, .live, "Rising"),
            (.high, .short, .dead, "Low"),
            (.high, .long, .dead, "Low"),
        ]
        XCTAssertEqual(
            expected.count,
            ConsonantClass.allCases.count * Duration.allCases.count * ToneDerivation.Ending.allCases.count
        )
        for (cls, duration, ending, tone) in expected {
            XCTAssertEqual(
                derive(cls, duration, ending).outcome, .tone(tone),
                "\(cls.rawValue) \(duration.rawValue) \(ending.rawValue)"
            )
        }
    }

    func test_unmarkedSteps_includeDurationOnlyWhenTheRuleDependsOnIt() {
        XCTAssertEqual(
            trace(derive(.low, .long, .dead)),
            ["no mark", "class low", "ending Dead", "duration Long", "rule Low-Long-Dead"]
        )
        XCTAssertEqual(
            trace(derive(.low, .short, .dead)),
            ["no mark", "class low", "ending Dead", "duration Short", "rule Low-Short-Dead/None"]
        )
        XCTAssertEqual(
            trace(derive(.high, .long, .live)),
            ["no mark", "class high", "ending Live", "rule High-Any-Live"]
        )
    }

    // MARK: - Tone marks

    func test_everyToneMarkAndClass_derivesTheToneItsRowStates() throws {
        var covered = 0
        var notCovered = 0
        for mark in marks {
            for entry in mark.classEntries {
                let cls = try XCTUnwrap(ConsonantClass(rawValue: entry.className.lowercased()))
                // The mark decides alone: every duration and ending agrees
                for duration in Duration.allCases {
                    for ending in ToneDerivation.Ending.allCases {
                        let derivation = derive(cls, duration, ending, mark: mark.mark)
                        let label = "\(entry.display) \(duration.rawValue) \(ending.rawValue)"
                        guard let tone = entry.tone else {
                            XCTAssertEqual(derivation.outcome, .notCovered(.markNotUsedWithClass), label)
                            XCTAssertNil(derivation.decidingStep, label)
                            continue
                        }
                        XCTAssertEqual(derivation.outcome, .tone(tone), label)
                        XCTAssertEqual(
                            trace(derivation),
                            ["mark \(mark.mark)", "class \(cls.rawValue)", "mark row \(mark.id) on \(cls.rawValue)"],
                            label
                        )
                    }
                }
                if entry.tone == nil { notCovered += 1 } else { covered += 1 }
            }
        }
        // ่ and ้ on three classes, ๊ and ๋ on mid only
        XCTAssertEqual(covered, 8)
        XCTAssertEqual(notCovered, 4)
    }

    // MARK: - Not covered

    func test_midOnlyMarkOnLowClass_isNotCovered() {
        let derivation = derive(.low, .long, .live, mark: "๊")
        XCTAssertEqual(derivation.outcome, .notCovered(.markNotUsedWithClass))
        XCTAssertNil(derivation.tone)
        XCTAssertNil(derivation.decidingStep)
        XCTAssertEqual(trace(derivation), ["mark ๊", "class low"])
    }

    func test_midOnlyMarkOnHighClass_isNotCovered() {
        XCTAssertEqual(derive(.high, .long, .live, mark: "๋").outcome, .notCovered(.markNotUsedWithClass))
    }

    /// ◌์ (thanthakhat) sits above a consonant like a tone mark but is not one
    func test_markOutsideTheTable_isNotCovered() {
        let derivation = derive(.mid, .long, .live, mark: "์")
        XCTAssertEqual(derivation.outcome, .notCovered(.unknownToneMark))
        XCTAssertNil(derivation.tone)
        XCTAssertEqual(trace(derivation), ["mark ์"])
    }

    func test_noMatchingRule_isNotCovered() {
        let withoutLowClass = rules.filter { $0.initialConsonant != "Low" }
        let derivation = ToneDerivation.derive(
            Input(consonantClass: .low, vowelDuration: .long, ending: .dead),
            rules: withoutLowClass,
            marks: marks
        )
        XCTAssertEqual(derivation.outcome, .notCovered(.noMatchingRule))
        XCTAssertNil(derivation.decidingStep)
        XCTAssertEqual(trace(derivation), ["no mark", "class low", "ending Dead"])
    }

    func test_twoMatchingRules_isNotCovered() {
        let conflicting = ToneRule(
            initialConsonant: "Mid", vowelDuration: "Long", end: "Live", tone: "High", samples: nil
        )
        let derivation = ToneDerivation.derive(
            Input(consonantClass: .mid, vowelDuration: .long, ending: .live),
            rules: rules + [conflicting],
            marks: marks
        )
        XCTAssertEqual(derivation.outcome, .notCovered(.ambiguousRules))
        XCTAssertNil(derivation.tone)
    }

    func test_ruleWithAnUnrecognizedEnding_matchesNothing() {
        let odd = ToneRule(
            initialConsonant: "Mid", vowelDuration: "Any", end: "Open", tone: "High", samples: nil
        )
        for ending in ToneDerivation.Ending.allCases {
            let derivation = ToneDerivation.derive(
                Input(consonantClass: .mid, vowelDuration: .short, ending: ending),
                rules: [odd],
                marks: marks
            )
            XCTAssertEqual(derivation.outcome, .notCovered(.noMatchingRule))
        }
    }
}

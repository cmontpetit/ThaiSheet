//
//  ThaiDisplayTests.swift
//  ThaiSheetTests
//

import XCTest
@testable import ThaiSheet

final class ThaiDisplayTests: XCTestCase {

    private let circle = "\u{25CC}"
    private let hair = "\u{200A}"

    // MARK: - Spacing vowels → explicit dotted circle

    func test_openShortA_usesExplicitCircle() {
        XCTAssertEqual(ThaiDisplay.placeholder("กะ"), "\(circle)ะ")
    }

    func test_longAaClosed_usesExplicitCircle() {
        XCTAssertEqual(ThaiDisplay.placeholder("กา-"), "\(circle)า-")
    }

    func test_preposedVowel_usesExplicitCircle() {
        XCTAssertEqual(ThaiDisplay.placeholder("เกาะ"), "เ\(circle)าะ")
    }

    func test_followingThaiLetter_usesExplicitCircle() {
        // ว is a full letter, not a combining mark
        XCTAssertEqual(ThaiDisplay.placeholder("กว-"), "\(circle)ว-")
    }

    func test_shortOClosed_usesHairSpace() {
        // ก็อ- (ล็อก pattern): ก carries the ็ mark
        XCTAssertEqual(ThaiDisplay.placeholder("ก็อ-"), "\(hair)\u{0E47}อ-")
    }

    func test_bareConsonantWithDash_usesExplicitCircle() {
        XCTAssertEqual(ThaiDisplay.placeholder("ก-"), "\(circle)-")
    }

    // MARK: - Above/below marks → hair space (renderer auto-inserts the circle)

    func test_maiHanAkat_usesHairSpace() {
        XCTAssertEqual(ThaiDisplay.placeholder("กั-"), "\(hair)\u{0E31}-")
    }

    func test_saraIClosed_usesHairSpace() {
        XCTAssertEqual(ThaiDisplay.placeholder("กิ-"), "\(hair)\u{0E34}-")
    }

    func test_saraAm_usesHairSpace() {
        XCTAssertEqual(ThaiDisplay.placeholder("กำ"), "\(hair)\u{0E33}")
    }

    func test_preposedWithAboveMark_usesHairSpace() {
        XCTAssertEqual(ThaiDisplay.placeholder("เก็-"), "เ\(hair)\u{0E47}-")
        XCTAssertEqual(ThaiDisplay.placeholder("แก็-"), "แ\(hair)\u{0E47}-")
        XCTAssertEqual(ThaiDisplay.placeholder("เกิ-"), "เ\(hair)\u{0E34}-")
    }

    func test_compoundVowel_iaShort_usesHairSpace() {
        XCTAssertEqual(ThaiDisplay.placeholder("เกียะ"), "เ\(hair)\u{0E35}ยะ")
    }

    // MARK: - Tone marks

    func test_toneMarks_useHairSpace() {
        XCTAssertEqual(ThaiDisplay.placeholder("ก่"), "\(hair)\u{0E48}")
        XCTAssertEqual(ThaiDisplay.placeholder("ก้"), "\(hair)\u{0E49}")
        XCTAssertEqual(ThaiDisplay.placeholder("ก๊"), "\(hair)\u{0E4A}")
        XCTAssertEqual(ThaiDisplay.placeholder("ก๋"), "\(hair)\u{0E4B}")
    }

    func test_bareConsonant_noMark_usesExplicitCircle() {
        XCTAssertEqual(ThaiDisplay.placeholder("ก"), circle)
    }

    // MARK: - Search normalization

    func test_normalizeSearch_prependsPlaceholderToCombiningMark() {
        XCTAssertEqual(ThaiDisplay.normalizeSearch("\u{0E34}"), "ก\u{0E34}")
        XCTAssertEqual(ThaiDisplay.normalizeSearch("\u{0E48}"), "ก\u{0E48}")
    }

    func test_normalizeSearch_leavesRegularTextUnchanged() {
        XCTAssertEqual(ThaiDisplay.normalizeSearch("กา"), "กา")
        XCTAssertEqual(ThaiDisplay.normalizeSearch("เ"), "เ")
        XCTAssertEqual(ThaiDisplay.normalizeSearch("kh"), "kh")
        XCTAssertEqual(ThaiDisplay.normalizeSearch(""), "")
    }

    // MARK: - Forms without ก are unchanged

    func test_rareVowelsWithoutPlaceholder_areUnchanged() {
        XCTAssertEqual(ThaiDisplay.placeholder("ฤ"), "ฤ")
        XCTAssertEqual(ThaiDisplay.placeholder("ฤๅ"), "ฤๅ")
    }

    // MARK: - All bundled vowel forms produce no bare ก

    func test_allVowelForms_haveNoPlaceholderConsonantLeft() {
        for vowel in Vowel.loadAll() {
            for form in [vowel.short.closed, vowel.short.open, vowel.long.closed, vowel.long.open] {
                guard let form else { continue }
                let display = ThaiDisplay.placeholder(form)
                XCTAssertFalse(
                    display.unicodeScalars.contains("ก"),
                    "\(form) should not display a ก placeholder (got \(display))"
                )
            }
        }
    }
}

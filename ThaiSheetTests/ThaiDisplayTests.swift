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
        XCTAssertEqual(ThaiDisplay.vowelPlaceholder("กะ"), "\(circle)ะ")
    }

    func test_longAaClosed_usesExplicitCircle() {
        XCTAssertEqual(ThaiDisplay.vowelPlaceholder("กา-"), "\(circle)า-")
    }

    func test_preposedVowel_usesExplicitCircle() {
        XCTAssertEqual(ThaiDisplay.vowelPlaceholder("เกาะ"), "เ\(circle)าะ")
    }

    func test_followingThaiLetter_usesExplicitCircle() {
        // อ is a full letter, not a combining mark
        XCTAssertEqual(ThaiDisplay.vowelPlaceholder("กอ็-"), "\(circle)อ็-")
    }

    func test_bareConsonantWithDash_usesExplicitCircle() {
        XCTAssertEqual(ThaiDisplay.vowelPlaceholder("ก-"), "\(circle)-")
    }

    // MARK: - Above/below marks → hair space (renderer auto-inserts the circle)

    func test_maiHanAkat_usesHairSpace() {
        XCTAssertEqual(ThaiDisplay.vowelPlaceholder("กั-"), "\(hair)\u{0E31}-")
    }

    func test_saraIClosed_usesHairSpace() {
        XCTAssertEqual(ThaiDisplay.vowelPlaceholder("กิ-"), "\(hair)\u{0E34}-")
    }

    func test_saraAm_usesHairSpace() {
        XCTAssertEqual(ThaiDisplay.vowelPlaceholder("กำ"), "\(hair)\u{0E33}")
    }

    func test_preposedWithAboveMark_usesHairSpace() {
        XCTAssertEqual(ThaiDisplay.vowelPlaceholder("เก็-"), "เ\(hair)\u{0E47}-")
        XCTAssertEqual(ThaiDisplay.vowelPlaceholder("แก็-"), "แ\(hair)\u{0E47}-")
        XCTAssertEqual(ThaiDisplay.vowelPlaceholder("เกิ-"), "เ\(hair)\u{0E34}-")
    }

    func test_compoundVowel_iaShort_usesHairSpace() {
        XCTAssertEqual(ThaiDisplay.vowelPlaceholder("เกียะ"), "เ\(hair)\u{0E35}ยะ")
    }

    // MARK: - Forms without ก are unchanged

    func test_rareVowelsWithoutPlaceholder_areUnchanged() {
        XCTAssertEqual(ThaiDisplay.vowelPlaceholder("ฤ"), "ฤ")
        XCTAssertEqual(ThaiDisplay.vowelPlaceholder("ฤๅ"), "ฤๅ")
    }

    // MARK: - All bundled vowel forms produce no bare ก

    func test_allVowelForms_haveNoPlaceholderConsonantLeft() {
        for vowel in Vowel.loadAll() {
            for form in [vowel.short.closed, vowel.short.open, vowel.long.closed, vowel.long.open] {
                guard let form else { continue }
                let display = ThaiDisplay.vowelPlaceholder(form)
                XCTAssertFalse(
                    display.unicodeScalars.contains("ก"),
                    "\(form) should not display a ก placeholder (got \(display))"
                )
            }
        }
    }
}

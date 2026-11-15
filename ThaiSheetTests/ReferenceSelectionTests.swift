import XCTest
@testable import ThaiSheet

@MainActor
final class ReferenceSelectionTests: XCTestCase {
    func test_initialSelectionWaitsForContainerSizeBeforePresentingSheet() {
        let selection = ReferenceSelection()
        selection.showDetails(.consonant("ค"))
        XCTAssertFalse(selection.isSheetPresented)
        selection.setExpanded(true)
        XCTAssertFalse(selection.isSheetPresented)
        selection.setExpanded(false)
        XCTAssertTrue(selection.isSheetPresented)
    }

    func test_compactAudioTapLeavesDetailsClosedButExplicitDetailsOpensSheet() {
        let selection = ReferenceSelection()
        let item = ReferenceItem.consonant("ก")
        selection.selectFromTap(item)
        XCTAssertNil(selection.item)
        XCTAssertFalse(selection.wantsSheet)

        selection.showDetails(item)
        XCTAssertEqual(selection.item, item)
        XCTAssertTrue(selection.wantsSheet)
        selection.dismissSheet()
        XCTAssertFalse(selection.wantsSheet)
    }

    func test_openSheetMovesIntoPaneAndBackWithoutLosingExactCell() {
        let selection = ReferenceSelection()
        let item = ReferenceItem.vowel(id: "a", variant: .shortClosed, text: "กั-")
        selection.showDetails(item)
        selection.setExpanded(true)
        // The old sheet's dismissal callback arrives after expanding.
        selection.dismissSheet()
        XCTAssertEqual(selection.item, item)
        XCTAssertFalse(selection.wantsSheet)

        selection.setExpanded(false)
        XCTAssertEqual(selection.item, item)
        XCTAssertTrue(selection.wantsSheet)
    }

    func test_expandedTapSelectsWithoutSheetAndClearRemovesBothPresentations() {
        let selection = ReferenceSelection()
        selection.setExpanded(true)
        selection.selectFromTap(.cluster("กร:initial"))
        XCTAssertEqual(selection.item, .cluster("กร:initial"))
        XCTAssertFalse(selection.wantsSheet)
        selection.setExpanded(false)
        XCTAssertTrue(selection.wantsSheet)
        selection.clear()
        XCTAssertNil(selection.item)
        XCTAssertFalse(selection.wantsSheet)
        selection.setExpanded(true)
        selection.setExpanded(false)
        XCTAssertFalse(selection.wantsSheet)
    }

    func test_vowelCellsHaveDistinctSelectionsButShareTheirReading() {
        let closed = ReferenceItem.vowel(id: "a", variant: .shortClosed, text: "กั-")
        let open = ReferenceItem.vowel(id: "a", variant: .shortOpen, text: "กะ")
        XCTAssertNotEqual(closed.id, open.id)
        XCTAssertEqual(closed.concealID, open.concealID)
        let practice = PracticeMode()
        practice.toggleActive()
        practice.reveal(closed.concealID)
        practice.reveal(open.concealID)
        XCTAssertFalse(practice.isConcealed(closed.concealID))
        XCTAssertFalse(practice.isConcealed(open.concealID))
    }

    func test_toneMarkColumnsHaveIndependentReadings() {
        let low = ReferenceItem.toneMark(id: "่", soundKey: "ค่า")
        let mid = ReferenceItem.toneMark(id: "่", soundKey: "ก่า")
        XCTAssertNotEqual(low.id, mid.id)
        let practice = PracticeMode()
        practice.toggleActive()
        practice.handleTap(low.concealID)
        XCTAssertFalse(practice.isConcealed(low.concealID))
        XCTAssertTrue(practice.isConcealed(mid.concealID))
        practice.handleTap(mid.concealID)
        XCTAssertTrue(practice.isConcealed(low.concealID))
        XCTAssertFalse(practice.isConcealed(mid.concealID))
    }
}

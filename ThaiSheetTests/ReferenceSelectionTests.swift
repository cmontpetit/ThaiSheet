import XCTest
@testable import ThaiSheet

@MainActor
final class ReferenceSelectionTests: XCTestCase {
    private let wideViewport = CGSize(width: 1000, height: 750)
    private let compactViewport = CGSize(width: 650, height: 1000)
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

    func test_foldOnAnotherTabPreservesSelectionWithoutReopeningSheet() {
        let selection = ReferenceSelection()
        let item = ReferenceItem.consonant("ค")
        selection.setExpanded(true, viewportSize: wideViewport)
        selection.selectFromTap(item)
        selection.setReferenceActive(false, viewportSize: wideViewport)
        selection.setExpanded(false, viewportSize: compactViewport)
        XCTAssertFalse(selection.wantsSheet)
        selection.setReferenceActive(true, viewportSize: compactViewport)
        selection.setExpanded(false, viewportSize: compactViewport)
        XCTAssertEqual(selection.item, item)
        XCTAssertFalse(selection.isSheetPresented)
        XCTAssertTrue(selection.isVisiblySelected(item))

        selection.showDetails(item)
        XCTAssertTrue(selection.isSheetPresented, "An explicit request still opens details")
        selection.dismissSheet()
        selection.setExpanded(true, viewportSize: wideViewport)
        selection.setExpanded(false, viewportSize: compactViewport)
        XCTAssertTrue(selection.isSheetPresented, "A later fold on Reference still hands off")
    }

    func test_firstMeasurementAfterReturningHandlesLayoutsThatWereNotUpdatedWhileHidden() {
        let selection = ReferenceSelection()
        let item = ReferenceItem.vowel(id: "a", variant: .shortClosed, text: "กั-")
        selection.setExpanded(true, viewportSize: wideViewport)
        selection.selectFromTap(item)
        selection.setReferenceActive(false, viewportSize: wideViewport)
        // No measurement occurs while hidden, as with a detached tab's view.
        selection.setReferenceActive(true, viewportSize: compactViewport)
        selection.setExpanded(false, viewportSize: compactViewport)
        XCTAssertEqual(selection.item, item)
        XCTAssertFalse(selection.isSheetPresented)
        selection.setExpanded(true, viewportSize: wideViewport)
        selection.setExpanded(false, viewportSize: compactViewport)
        XCTAssertTrue(selection.isSheetPresented)
    }

    func test_returningToExpandedReferenceRestoresPaneAndRearmsVisibleFoldHandoff() {
        let selection = ReferenceSelection()
        let item = ReferenceItem.cluster("กร:initial")
        selection.setExpanded(true, viewportSize: wideViewport)
        selection.selectFromTap(item)
        selection.setReferenceActive(false, viewportSize: wideViewport)
        selection.setReferenceActive(true, viewportSize: wideViewport)
        selection.setExpanded(true, viewportSize: wideViewport)
        XCTAssertEqual(selection.item, item)
        XCTAssertTrue(selection.isExpanded)
        XCTAssertFalse(selection.isSheetPresented)
        selection.setExpanded(false, viewportSize: compactViewport)
        XCTAssertTrue(selection.isSheetPresented)
    }

    func test_obsoleteWideReadingBeforeCompactReturnCannotOpenSheet() {
        let selection = ReferenceSelection()
        let item = ReferenceItem.consonant("ถ")
        selection.setExpanded(true, viewportSize: wideViewport)
        selection.selectFromTap(item)
        selection.setReferenceActive(false, viewportSize: wideViewport)
        selection.setReferenceActive(true, viewportSize: compactViewport)
        // Both nested width readings can be obsolete. Repeating them must not
        // consume the protection while the real outer viewport stays compact.
        for _ in 0..<5 {
            selection.setExpanded(true, viewportSize: compactViewport)
            selection.setExpanded(false, viewportSize: compactViewport)
            XCTAssertEqual(selection.item, item)
            XCTAssertFalse(selection.isSheetPresented)
            XCTAssertTrue(selection.isVisiblySelected(item))
        }
        // A genuine viewport change while Reference is active rearms handoff.
        selection.setExpanded(true, viewportSize: wideViewport)
        selection.setExpanded(false, viewportSize: compactViewport)
        XCTAssertTrue(selection.isSheetPresented)
    }

    func test_compactDetailsDismissalDoesNotLeaveAnOrdinaryRowSelected() {
        let selection = ReferenceSelection()
        let item = ReferenceItem.consonant("ก")
        selection.setExpanded(false, viewportSize: compactViewport)
        selection.showDetails(item)
        XCTAssertFalse(selection.isVisiblySelected(item))
        selection.dismissSheet()
        XCTAssertFalse(selection.isVisiblySelected(item))
        XCTAssertNil(selection.retainedCompactSelectionID)

        selection.setExpanded(true, viewportSize: wideViewport)
        XCTAssertTrue(selection.isVisiblySelected(item))
        selection.setExpanded(false, viewportSize: compactViewport)
        selection.dismissSheet()
        XCTAssertTrue(selection.isVisiblySelected(item), "Only a folded selection stays outlined")
        selection.showDetails(item)
        selection.dismissSheet()
        XCTAssertFalse(selection.isVisiblySelected(item), "An explicit compact request clears the fold marker")
        selection.clear()
        XCTAssertNil(selection.retainedCompactSelectionID)
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

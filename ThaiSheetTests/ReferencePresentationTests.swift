import SwiftUI
import XCTest
@testable import ThaiSheet

@MainActor
final class ReferencePresentationTests: XCTestCase {
    func test_searchWithSelectedToneMarkKeepsInlineDetailsAndKeyboardFocus() async throws {
        try await assertSearchKeepsDetailsStable(.toneMark(id: "่", soundKey: "ค่า"))
    }

    func test_searchWithSelectedToneRuleKeepsInlineDetailsAndKeyboardFocus() async throws {
        try await assertSearchKeepsDetailsStable(.toneRule("Low-Short-Dead/None"))
    }

    private func assertSearchKeepsDetailsStable(
        _ item: ReferenceItem,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let suiteName = "ReferenceSearchTests_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = FlashcardSettings(defaults: defaults)
        let selection = ReferenceSelection()
        selection.showDetails(item)
        let browser = CheatsheetBrowserView(
            settings: settings,
            highlighted: .constant([:]),
            flashcardStarting: .constant([:]),
            selectedTab: .constant(.reference),
            referenceSelection: selection,
            referenceType: .tones
        )
        .environment(\.flashcardSettings, settings)
        .environment(\.learningModel, LearningModel(store: defaults))
        let host = UIHostingController(rootView: browser)
        let window = show(host)
        defer { window.endEditing(true); window.isHidden = true }
        host.view.frame = CGRect(x: 0, y: 0, width: 1000, height: 650)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        await waitFor { selection.isExpanded && self.searchField(in: window) != nil }
        let field = try XCTUnwrap(searchField(in: window), file: file, line: line)
        // A real input view exercises keyboard safe-area changes, independently
        // of whether the simulator has a Mac hardware keyboard connected.
        field.inputView = UIView(frame: CGRect(x: 0, y: 0, width: 1000, height: 300))
        let keyboardShown = XCTNSNotificationExpectation(name: UIResponder.keyboardDidShowNotification)
        keyboardShown.handler = { notification in
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
            return (frame?.cgRectValue.height ?? 0) >= 200
        }
        window.makeKeyAndVisible()
        XCTAssertTrue(field.becomeFirstResponder(), file: file, line: line)
        await fulfillment(of: [keyboardShown], timeout: 3)

        // Check throughout the transition, rather than only its final frame:
        // a sheet stealing focus and closing again is itself the regression.
        for _ in 0..<20 {
            guard selection.isExpanded, host.presentedViewController == nil, field.isFirstResponder else {
                XCTFail("Search changed detail presentation or lost keyboard focus: expanded=\(selection.isExpanded), sheet=\(selection.isSheetPresented), focus=\(field.isFirstResponder)", file: file, line: line)
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(selection.item, item, file: file, line: line)
    }

    private func searchField(in view: UIView) -> UISearchTextField? {
        if let field = view as? UISearchTextField { return field }
        return view.subviews.lazy.compactMap { self.searchField(in: $0) }.first
    }

    func test_concealedPaneDoesNotOpenAnAnswerSheetWhenNarrowed() async {
        let selection = ReferenceSelection()
        let item = ReferenceItem.consonant("ค")
        selection.showDetails(item)
        let practice = PracticeMode()
        practice.toggleActive()
        let view = ReferenceBrowserLayout(selection: selection) {
            Text("Tables")
        } detail: {
            ReferenceDetailPane(selection: selection) { _ in Text("Answer") }
        }
        .environment(\.practiceMode, practice)
        let host = UIHostingController(rootView: view)
        let window = show(host)
        defer { window.isHidden = true }
        await waitFor { selection.isExpanded }

        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 620)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        await waitFor { !selection.isExpanded }
        XCTAssertFalse(selection.isSheetPresented, "Resizing must not reveal a concealed answer")
        XCTAssertEqual(selection.item, item)
        XCTAssertTrue(practice.isConcealed(item.concealID))
    }

    func test_browserActuallyPresentsAndDismissesSheetWhenContainerChanges() async {
        let suiteName = "ReferencePresentationTests_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = FlashcardSettings(defaults: defaults)
        let selection = ReferenceSelection()
        let item = ReferenceItem.consonant("ค")
        selection.showDetails(item)
        let tab = ReferenceViewObservation()
        let browser = CheatsheetBrowserView(
            settings: settings,
            highlighted: .constant([:]),
            flashcardStarting: .constant([:]),
            selectedTab: Binding(get: { tab.activeTab }, set: { tab.activeTab = $0 }),
            referenceSelection: selection
        )
        .environment(\.flashcardSettings, settings)
        .environment(\.learningModel, LearningModel(store: defaults))
        let host = UIHostingController(rootView: browser)
        let window = show(host)
        defer { window.isHidden = true }

        func resize(_ size: CGSize) {
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
        }

        resize(CGSize(width: 1000, height: 650))
        await waitFor { selection.hasMeasuredContainer && selection.isExpanded }
        XCTAssertNil(host.presentedViewController, "Wide startup must not flash a compact sheet")

        resize(CGSize(width: 390, height: 620))
        await waitFor { !selection.isExpanded && host.presentedViewController != nil }
        XCTAssertEqual(selection.item, item)

        resize(CGSize(width: 1000, height: 650))
        await waitFor { selection.isExpanded && host.presentedViewController == nil }
        XCTAssertEqual(selection.item, item)

        resize(CGSize(width: 390, height: 620))
        await waitFor { host.presentedViewController != nil }
        selection.dismissSheet()
        await waitFor { host.presentedViewController == nil }
        XCTAssertEqual(selection.item, item)

        tab.activeTab = .flashcards
        resize(CGSize(width: 1000, height: 650))
        await waitFor { selection.isExpanded }
        resize(CGSize(width: 390, height: 620))
        await waitFor { !selection.isExpanded }
        XCTAssertNil(host.presentedViewController, "The Reference sheet must not appear over Flashcards")
        tab.activeTab = .reference
        await waitFor { host.presentedViewController != nil }
        selection.dismissSheet()
        await waitFor { host.presentedViewController == nil }
    }

    func test_paneRemovesAnswerContentWhenRehiddenOrPracticeIsActivated() async {
        let selection = ReferenceSelection()
        selection.setExpanded(true)
        let item = ReferenceItem.consonant("ก")
        selection.selectFromTap(item)
        let practice = PracticeMode()
        let observation = ReferenceViewObservation()
        let pane = ReferenceDetailPane(selection: selection) { _ in
            Text("Secret reading and sample words")
                .onAppear { observation.answerIsPresent = true }
                .onDisappear { observation.answerIsPresent = false }
        }
        .environment(\.practiceMode, practice)
        let host = UIHostingController(rootView: pane)
        let window = show(host)
        defer { window.isHidden = true }

        await waitFor { observation.answerIsPresent }
        practice.toggleActive()
        await waitFor { !observation.answerIsPresent }
        practice.handleTap(item.concealID)
        await waitFor { observation.answerIsPresent }
        practice.handleTap(item.concealID)
        await waitFor { !observation.answerIsPresent }

        practice.toggleActive()
        await waitFor { observation.answerIsPresent }
        practice.toggleActive()
        await waitFor { !observation.answerIsPresent }
        XCTAssertEqual(selection.item, item, "Concealment must not clear the selection")
    }

    func test_resizingPreservesBrowserIdentityAndMovesSelectionBetweenPresentations() async {
        let selection = ReferenceSelection()
        let observation = ReferenceViewObservation()
        let host = UIHostingController(rootView: ReferenceLayoutHarness(selection: selection, observation: observation))
        let window = show(host)
        defer { window.isHidden = true }

        func resize(_ size: CGSize) {
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
        }

        resize(CGSize(width: 390, height: 620))
        await waitFor { observation.browserIdentity != nil }
        let originalIdentity = observation.browserIdentity
        let item = ReferenceItem.toneMark(id: "่", soundKey: "ค่า")
        selection.showDetails(item)

        resize(CGSize(width: 867, height: 550))
        await waitFor { selection.isExpanded && observation.paneIsPresent }
        XCTAssertFalse(selection.wantsSheet)
        XCTAssertEqual(observation.browserIdentity, originalIdentity)
        XCTAssertEqual(selection.item, item)

        resize(CGSize(width: 500, height: 550))
        await waitFor { !selection.isExpanded && !observation.paneIsPresent }
        XCTAssertTrue(selection.wantsSheet)
        XCTAssertEqual(observation.browserIdentity, originalIdentity)
        XCTAssertEqual(selection.item, item)

        resize(CGSize(width: 1000, height: 650))
        await waitFor { selection.isExpanded }
        host.rootView = ReferenceLayoutHarness(selection: selection, observation: observation, typeSize: .accessibility3)
        await waitFor { !selection.isExpanded }
        XCTAssertEqual(observation.browserIdentity, originalIdentity)
        XCTAssertEqual(selection.item, item)

        host.rootView = ReferenceLayoutHarness(selection: selection, observation: observation)
        resize(CGSize(width: 867, height: 320))
        await waitFor { !selection.isExpanded && !observation.paneIsPresent }
        XCTAssertEqual(observation.browserIdentity, originalIdentity)
    }

    private func show<V: View>(_ host: UIHostingController<V>) -> UIWindow {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: 1100, height: 800)
        let container = UIViewController()
        window.rootViewController = container
        container.view.frame = window.bounds
        host.view.frame = container.view.bounds
        container.addChild(host)
        container.view.addSubview(host.view)
        host.didMove(toParent: container)
        window.makeKeyAndVisible()
        return window
    }

    private func waitFor(file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) async {
        for _ in 0..<40 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Reference presentation did not reach the expected state", file: file, line: line)
    }
}

@MainActor
@Observable
private final class ReferenceViewObservation {
    var activeTab: AppTab = .reference
    var answerIsPresent = false
    var paneIsPresent = false
    var browserIdentity: UUID?
}

private struct ReferenceLayoutHarness: View {
    let selection: ReferenceSelection
    let observation: ReferenceViewObservation
    var typeSize: DynamicTypeSize = .large

    var body: some View {
        ReferenceBrowserLayout(selection: selection) {
            BrowserIdentityProbe(observation: observation)
        } detail: {
            Text("Details")
                .onAppear { observation.paneIsPresent = true }
                .onDisappear { observation.paneIsPresent = false }
        }
        .environment(\.dynamicTypeSize, typeSize)
    }
}

private struct BrowserIdentityProbe: View {
    let observation: ReferenceViewObservation
    @State private var identity = UUID()

    var body: some View {
        Text("Tables, search, and filters")
            .onAppear { observation.browserIdentity = identity }
    }
}

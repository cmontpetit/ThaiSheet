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

    func test_rotatingWithPendingToneMarkKeepsSearchStable() async throws {
        try await assertSearchKeepsDetailsStable(
            .toneMark(id: "้", soundKey: "ค้า"),
            markedText: "้",
            rotates: true
        )
    }

    func test_rotatingWithPendingVowelMarkKeepsSearchStable() async throws {
        try await assertSearchKeepsDetailsStable(
            .vowel(id: "a", variant: .shortClosed, text: "กั-"),
            referenceType: .vowels,
            markedText: "ั",
            rotates: true
        )
    }

    func test_queryStaysVisibleAfterEndingSearchResizingAndSwitchingTabs() async throws {
        let suiteName = "ReferenceSearchVisibilityTests_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = FlashcardSettings(defaults: defaults)
        let navigation = ReferenceViewObservation()
        let activeTab = Binding(get: { navigation.activeTab }, set: { navigation.activeTab = $0 })
        let highlighted = ReferenceSearchNavigation()
        let browser = CheatsheetBrowserView(
            settings: settings,
            highlighted: Binding(get: { highlighted.items }, set: { highlighted.items = $0 }),
            flashcardStarting: .constant([:]),
            selectedTab: activeTab
        )
        let root = TabView(selection: activeTab) {
            browser.tabItem { Label("Reference", systemImage: "book") }.tag(AppTab.reference)
            Text("Flashcards").tabItem { Label("Flashcards", systemImage: "rectangle.on.rectangle") }.tag(AppTab.flashcards)
        }
        .environment(\.flashcardSettings, settings)
        .environment(\.learningModel, LearningModel(store: defaults))
        let host = UIHostingController(rootView: root)
        let window = show(host)
        defer { window.endEditing(true); window.isHidden = true }
        await waitFor { self.searchField(in: window) != nil }
        let field = try XCTUnwrap(searchField(in: window))
        field.inputView = UIView(frame: CGRect(x: 0, y: 0, width: 1000, height: 300))
        XCTAssertTrue(field.becomeFirstResponder())
        field.insertText("ถ")
        field.sendActions(for: .editingChanged)
        await waitFor { self.referenceSections(in: window)?.titleForSegment(at: 0)?.hasSuffix("(1)") == true }
        field.resignFirstResponder()
        await waitFor { !field.isFirstResponder }

        for size in [CGSize(width: 650, height: 1000), CGSize(width: 1000, height: 650)] {
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            // Both the Reference section and the app tab can change while the
            // keyboard is closed. Neither should conceal an active query.
            highlighted.items = [.vowel: "กั-"]
            try await Task.sleep(for: .milliseconds(100))
            navigation.activeTab = .flashcards
            try await Task.sleep(for: .milliseconds(100))
            navigation.activeTab = .reference
            await waitFor { self.searchField(in: window)?.window != nil }
            let visibleField = try XCTUnwrap(searchField(in: window))
            XCTAssertEqual(visibleField.text, "ถ")
            XCTAssertTrue(referenceSections(in: window)?.titleForSegment(at: 0)?.hasSuffix("(1)") == true)
            XCTAssertFalse(visibleField.isFirstResponder)
            XCTAssertFalse(visibleField.isHidden)
            XCTAssertGreaterThan(visibleField.bounds.width, 100)
            XCTAssertEqual(visibleField.clearButtonMode, .always)
        }

        // Clearing the displayed field must also clear the retained filtering
        // query, rather than bringing it back on the next tab presentation.
        let visibleField = try XCTUnwrap(searchField(in: window))
        visibleField.text = ""
        visibleField.sendActions(for: .editingChanged)
        navigation.activeTab = .flashcards
        try await Task.sleep(for: .milliseconds(100))
        navigation.activeTab = .reference
        await waitFor { self.searchField(in: window)?.window != nil }
        XCTAssertEqual(searchField(in: window)?.text, "")
        await waitFor { self.referenceSections(in: window)?.titleForSegment(at: 0)?.contains("(") == false }
    }

    func test_queryStaysVisibleWhenCompactDetailsRotateIntoInlinePane() async throws {
        let suiteName = "ReferenceSearchHandoffTests_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = FlashcardSettings(defaults: defaults)
        let selection = ReferenceSelection()
        let browser = CheatsheetBrowserView(
            settings: settings,
            highlighted: .constant([:]),
            flashcardStarting: .constant([:]),
            selectedTab: .constant(.reference),
            referenceSelection: selection
        )
        .environment(\.flashcardSettings, settings)
        .environment(\.learningModel, LearningModel(store: defaults))
        let host = UIHostingController(rootView: browser)
        let window = show(host)
        defer { window.endEditing(true); window.isHidden = true }

        func resize(_ size: CGSize) {
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
        }

        resize(CGSize(width: 650, height: 1000))
        await waitFor { selection.hasMeasuredContainer && !selection.isExpanded && self.searchField(in: window) != nil }
        let field = try XCTUnwrap(searchField(in: window))
        field.inputView = UIView(frame: CGRect(x: 0, y: 0, width: 650, height: 300))
        XCTAssertTrue(field.becomeFirstResponder())
        field.insertText("ถ")
        field.sendActions(for: .editingChanged)
        await waitFor { self.referenceSections(in: window)?.titleForSegment(at: 0)?.hasSuffix("(1)") == true }

        // The same action as a row's long press: search finishes before the
        // compact popup opens, then rotation hands it to the inline pane.
        let item = ReferenceItem.consonant("ถ")
        selection.showDetails(item)
        await waitFor { host.presentedViewController != nil && !field.isFirstResponder }
        XCTAssertEqual(field.text, "ถ")
        resize(CGSize(width: 1000, height: 650))
        await waitFor { selection.isExpanded && host.presentedViewController == nil }
        XCTAssertEqual(searchField(in: window)?.text, "ถ")
        XCTAssertTrue(referenceSections(in: window)?.titleForSegment(at: 0)?.hasSuffix("(1)") == true)
        XCTAssertEqual(selection.item, item)
        XCTAssertFalse(field.isHidden)
    }

    private func assertSearchKeepsDetailsStable(
        _ item: ReferenceItem,
        referenceType: CheatsheetEntryType = .tones,
        markedText: String? = nil,
        rotates: Bool = false,
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
            referenceType: referenceType
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

        if let markedText {
            // Thai marks can be in an IME composition while waiting for a base
            // consonant. Keep that state through filtering and repeated resizes.
            field.setMarkedText(markedText, selectedRange: NSRange(location: markedText.utf16.count, length: 0))
            field.sendActions(for: .editingChanged)
            XCTAssertNotNil(field.markedTextRange, file: file, line: line)
        }

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
        if let markedText {
            XCTAssertEqual(field.text, markedText, file: file, line: line)
            XCTAssertNotNil(field.markedTextRange, file: file, line: line)
        }

        guard rotates else { return }
        for size in [CGSize(width: 650, height: 1000), CGSize(width: 1000, height: 650), CGSize(width: 650, height: 1000)] {
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            let expanded = size.width > size.height
            await waitFor { selection.isExpanded == expanded }
            for _ in 0..<10 {
                guard !selection.isSheetPresented, host.presentedViewController == nil, field.isFirstResponder else {
                    XCTFail("Rotation opened a detail popup or interrupted search", file: file, line: line)
                    return
                }
                try await Task.sleep(for: .milliseconds(50))
            }
            XCTAssertEqual(selection.item, item, file: file, line: line)
            if let markedText {
                XCTAssertEqual(field.text, markedText, file: file, line: line)
                XCTAssertNotNil(field.markedTextRange, file: file, line: line)
            }
        }

        // An explicit compact Show details action still works during search.
        selection.showDetails(item)
        await waitFor { host.presentedViewController != nil && !field.isFirstResponder }
        XCTAssertEqual(selection.item, item, file: file, line: line)
        selection.dismissSheet()
        await waitFor { host.presentedViewController == nil }
    }

    private func referenceSections(in view: UIView) -> UISegmentedControl? {
        if let control = view as? UISegmentedControl { return control }
        return view.subviews.lazy.compactMap { self.referenceSections(in: $0) }.first
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
        await waitFor { selection.isReferenceActive }
        // Check across subsequent UI updates: returning must not queue a popup
        // that appears after the first frame, and the selected cell stays put.
        for _ in 0..<10 {
            XCTAssertNil(host.presentedViewController)
            XCTAssertFalse(selection.isSheetPresented)
            try? await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(selection.item, item)
        selection.showDetails(item)
        await waitFor { host.presentedViewController != nil }
        resize(CGSize(width: 1000, height: 650))
        await waitFor { selection.isExpanded && host.presentedViewController == nil }
        resize(CGSize(width: 390, height: 620))
        await waitFor { !selection.isExpanded && host.presentedViewController != nil }
        selection.dismissSheet()
        await waitFor { host.presentedViewController == nil }
    }

    func test_actualTabReturnAfterFoldingKeepsSelectedRowAndQueryWithoutOpeningSheet() async throws {
        let suiteName = "ReferenceTabReturnTests_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = FlashcardSettings(defaults: defaults)
        let selection = ReferenceSelection()
        let navigation = ReferenceViewObservation()
        let activeTab = Binding(get: { navigation.activeTab }, set: { navigation.activeTab = $0 })
        let browser = CheatsheetBrowserView(
            settings: settings,
            highlighted: .constant([:]),
            flashcardStarting: .constant([:]),
            selectedTab: activeTab,
            referenceSelection: selection
        )
        let root = TabView(selection: activeTab) {
            browser.tabItem { Label("Reference", systemImage: "book") }.tag(AppTab.reference)
            Text("Flashcards").tabItem { Label("Flashcards", systemImage: "rectangle.on.rectangle") }.tag(AppTab.flashcards)
        }
        .environment(\.flashcardSettings, settings)
        .environment(\.learningModel, LearningModel(store: defaults))
        let host = UIHostingController(rootView: root)
        let window = show(host)
        defer { window.endEditing(true); window.isHidden = true }

        func resize(_ size: CGSize) {
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
        }

        resize(CGSize(width: 1000, height: 750))
        await waitFor { selection.isExpanded && self.searchField(in: window) != nil }
        let field = try XCTUnwrap(searchField(in: window))
        field.insertText("ถ")
        field.sendActions(for: .editingChanged)
        await waitFor { self.referenceSections(in: window)?.titleForSegment(at: 0)?.hasSuffix("(1)") == true }
        let item = ReferenceItem.consonant("ถ")
        selection.selectFromTap(item)
        navigation.activeTab = .flashcards
        await waitFor { !selection.isReferenceActive }
        resize(CGSize(width: 650, height: 1000))
        navigation.activeTab = .reference
        await waitFor { selection.isReferenceActive && !selection.isExpanded && self.searchField(in: window) != nil }
        for _ in 0..<10 {
            XCTAssertNil(host.presentedViewController)
            XCTAssertFalse(selection.isSheetPresented)
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(selection.item, item)
        XCTAssertEqual(searchField(in: window)?.text, "ถ")
        XCTAssertEqual(referenceSections(in: window)?.selectedSegmentIndex, 0)
        XCTAssertTrue(referenceSections(in: window)?.titleForSegment(at: 0)?.hasSuffix("(1)") == true)

        resize(CGSize(width: 1000, height: 750))
        await waitFor { selection.isExpanded && host.presentedViewController == nil }
        navigation.activeTab = .flashcards
        await waitFor { !selection.isReferenceActive }
        navigation.activeTab = .reference
        await waitFor { selection.isReferenceActive && selection.isExpanded }
        XCTAssertEqual(selection.item, item)
        XCTAssertNil(host.presentedViewController)
        resize(CGSize(width: 650, height: 1000))
        await waitFor { !selection.isExpanded && host.presentedViewController != nil }
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

@MainActor
@Observable
private final class ReferenceSearchNavigation {
    var items: [FlashcardType: String] = [:]
}

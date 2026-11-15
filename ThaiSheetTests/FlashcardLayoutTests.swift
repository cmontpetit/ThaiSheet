import SwiftUI
import XCTest
@testable import ThaiSheet

@MainActor
final class FlashcardLayoutTests: XCTestCase {
    func test_resizingRearrangesTheSameQuizViews() async throws {
        let observation = LayoutObservation()
        let host = UIHostingController(rootView: LayoutHarness(observation: observation))
        let container = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        window.rootViewController = container
        window.makeKeyAndVisible()
        container.addChild(host)
        container.view.addSubview(host.view)
        host.didMove(toParent: container)
        defer { window.isHidden = true }

        func resize(_ size: CGSize) {
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
        }

        resize(CGSize(width: 390, height: 620))
        await waitForLayout { observation.isStacked }
        let initialIDs = observation.snapshots.mapValues(\.identity)
        XCTAssertEqual(initialIDs.count, 2)

        resize(CGSize(width: 867, height: 550)) // Duo wide, after surrounding system UI
        await waitForLayout { observation.isExpanded }
        XCTAssertEqual(observation.snapshots.mapValues(\.identity), initialIDs)

        resize(CGSize(width: 500, height: 550)) // Narrow multitasking container
        await waitForLayout { observation.isStacked }
        XCTAssertEqual(observation.snapshots.mapValues(\.identity), initialIDs)

        resize(CGSize(width: 1000, height: 650)) // iPad
        await waitForLayout { observation.isExpanded }
        XCTAssertEqual(observation.snapshots.mapValues(\.identity), initialIDs)

        resize(CGSize(width: 867, height: 320)) // Wide but too short for the expanded design
        await waitForLayout { observation.isStacked }
        XCTAssertEqual(observation.snapshots.mapValues(\.identity), initialIDs)

        resize(CGSize(width: 867, height: 550))
        await waitForLayout { observation.isExpanded }
        host.rootView = LayoutHarness(observation: observation, typeSize: .accessibility3)
        await waitForLayout { observation.isStacked }
        XCTAssertEqual(observation.snapshots.mapValues(\.identity), initialIDs)
    }

    private func waitForLayout(file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) async {
        for _ in 0..<40 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("The quiz did not reach the expected layout", file: file, line: line)
    }
}

private struct LayoutHarness: View {
    let observation: LayoutObservation
    var typeSize: DynamicTypeSize = .large

    var body: some View {
        FlashcardLayout {
            LayoutProbe(name: "face", observation: observation)
        } summary: {
            Text("Summary")
        } question: {
            LayoutProbe(name: "question", observation: observation)
        }
        .coordinateSpace(name: "quiz")
        .environment(\.dynamicTypeSize, typeSize)
    }
}

private struct ProbeSnapshot: Equatable {
    let identity: UUID
    let frame: CGRect
}

private struct ProbeFrames: PreferenceKey {
    static let defaultValue: [String: ProbeSnapshot] = [:]
    static func reduce(value: inout [String: ProbeSnapshot], nextValue: () -> [String: ProbeSnapshot]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

@MainActor
private final class LayoutObservation {
    var snapshots: [String: ProbeSnapshot] = [:]

    var isExpanded: Bool {
        guard let face = snapshots["face"], let question = snapshots["question"] else { return false }
        return question.frame.minX > face.frame.maxX
    }

    var isStacked: Bool {
        guard let face = snapshots["face"], let question = snapshots["question"] else { return false }
        return question.frame.minY > face.frame.maxY
            && abs(question.frame.minX - face.frame.minX) < 1
    }
}

private struct LayoutProbe: View {
    let name: String
    let observation: LayoutObservation
    @State private var identity = UUID()

    var body: some View {
        Text(name)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ProbeFrames.self,
                        value: [name: ProbeSnapshot(identity: identity, frame: geometry.frame(in: .named("quiz")))]
                    )
                }
            }
            .onPreferenceChange(ProbeFrames.self) { snapshots in
                observation.snapshots.merge(snapshots, uniquingKeysWith: { _, new in new })
            }
    }
}

import SwiftUI

/// Keeps the browser in one stable location as the detail pane comes and goes.
struct ReferenceBrowserLayout<Browser: View, Detail: View>: View {
    let selection: ReferenceSelection
    var isSearching = false
    @ViewBuilder let browser: () -> Browser
    @ViewBuilder let detail: () -> Detail

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.practiceMode) private var practiceMode
    @Environment(\.referenceViewport) private var referenceViewport
    @ScaledMetric(relativeTo: .body) private var minimumTableWidth: CGFloat = 500
    @ScaledMetric(relativeTo: .body) private var minimumDetailWidth: CGFloat = 320
    @State private var containerSize: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let expanded = containerSize.width >= minimumTableWidth + minimumDetailWidth + 1
                && containerSize.height >= 440
            // The first layout pass can be zero-sized while navigation mounts.
            // It must not briefly present the compact sheet on a wide screen.
            let measuredExpanded: Bool? = containerSize.width > 0 && containerSize.height > 0
                ? expanded : nil
            let detailWidth = max(minimumDetailWidth, min(geometry.size.width * 0.36, minimumDetailWidth * 1.3))

            HStack(spacing: 0) {
                browser()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if expanded {
                    Divider()
                    detail()
                        .frame(width: detailWidth)
                        .frame(maxHeight: .infinity)
                        .environment(\.referenceDetailPlacement, .inline)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: expanded)
            .task(id: ReferencePresentationRequest(
                expanded: measuredExpanded,
                isSearching: isSearching,
                isReferenceActive: selection.isReferenceActive
            )) {
                // Safe-area insets can change again during the initial layout.
                // Coalesce those passes before asking UIKit to present a sheet;
                // a cancelled task must not leave an obsolete popup behind.
                await Task.yield()
                guard !Task.isCancelled, let expanded = measuredExpanded else { return }
                let concealed = selection.item.map { practiceMode.isConcealed($0.concealID) } ?? false
                // Let UIKit animate rotation without a second sheet animation.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    selection.setExpanded(
                        expanded,
                        readingIsConcealed: concealed,
                        allowsAutomaticSheet: !isSearching,
                        viewportSize: referenceViewport?.size
                    )
                }
            }
            .accessibilityIdentifier(expanded ? "reference.expanded" : "reference.compact")
        }
        .background {
            // Keyboard avoidance still resizes the visible scroll areas above.
            // Only this measurement ignores it: typing is not a fold/resize and
            // must not open a detail sheet that takes focus from search.
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.size, initial: true) { _, size in
                        guard size.width > 0, size.height > 0 else { return }
                        containerSize = size
                    }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }
}

private struct ReferencePresentationRequest: Equatable {
    let expanded: Bool?
    let isSearching: Bool
    let isReferenceActive: Bool
}

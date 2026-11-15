import SwiftUI

/// Keeps the browser in one stable location as the detail pane comes and goes.
struct ReferenceBrowserLayout<Browser: View, Detail: View>: View {
    let selection: ReferenceSelection
    @ViewBuilder let browser: () -> Browser
    @ViewBuilder let detail: () -> Detail

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.practiceMode) private var practiceMode
    @ScaledMetric(relativeTo: .body) private var minimumTableWidth: CGFloat = 500
    @ScaledMetric(relativeTo: .body) private var minimumDetailWidth: CGFloat = 320

    var body: some View {
        GeometryReader { geometry in
            let expanded = geometry.size.width >= minimumTableWidth + minimumDetailWidth + 1
                && geometry.size.height >= 440
            // The first layout pass can be zero-sized while navigation mounts.
            // It must not briefly present the compact sheet on a wide screen.
            let measuredExpanded: Bool? = geometry.size.width > 0 && geometry.size.height > 0
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
            .onChange(of: measuredExpanded, initial: true) { _, expanded in
                guard let expanded else { return }
                let concealed = selection.item.map { practiceMode.isConcealed($0.concealID) } ?? false
                selection.setExpanded(expanded, readingIsConcealed: concealed)
            }
            .accessibilityIdentifier(expanded ? "reference.expanded" : "reference.compact")
        }
    }
}

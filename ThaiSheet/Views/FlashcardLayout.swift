import SwiftUI

/// One view tree for both presentations, so folding never recreates quiz content.
struct FlashcardLayout<Face: View, Summary: View, Question: View>: View {
    @ViewBuilder let face: () -> Face
    @ViewBuilder let summary: () -> Summary
    @ViewBuilder let question: () -> Question

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var minimumColumnWidth: CGFloat = 360

    var body: some View {
        GeometryReader { geometry in
            let expanded = geometry.size.width >= minimumColumnWidth * 2 + 56
                && geometry.size.height >= 440
            let layout = expanded
                ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
                : AnyLayout(VStackLayout(spacing: 20))

            ScrollView {
                layout {
                    face()
                        .frame(maxWidth: .infinity)

                    VStack(spacing: 20) {
                        summary()
                        question()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .contentColumn(maxWidth: expanded ? 1100 : 700)
                // Animate only the rearrangement, leaving quiz interactions alone.
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: expanded)
            }
            .accessibilityIdentifier(expanded ? "flashcard.expanded" : "flashcard.stacked")
        }
    }
}

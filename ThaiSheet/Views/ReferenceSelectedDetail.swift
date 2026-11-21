import SwiftUI

/// Concealed answers are absent from the pane, including its accessibility tree.
/// Audio actions, notes, sample words, and tone colors can all reveal an answer.
struct ReferenceDetailPane<Detail: View>: View {
    let selection: ReferenceSelection
    @ViewBuilder let detail: (ReferenceItem) -> Detail
    @Environment(\.practiceMode) private var practiceMode

    var body: some View {
        if let item = selection.item {
            if practiceMode.isConcealed(item.concealID) {
                ContentUnavailableView {
                    Label("Reading hidden", systemImage: "eye.slash")
                } description: {
                    Text("Reveal the selected item to see its details.")
                } actions: {
                    Button("Reveal") { practiceMode.reveal(item.concealID) }
                        .buttonStyle(.bordered)
                }
                .accessibilityIdentifier("reference.detail.concealed")
            } else {
                detail(item)
                    .id(item.id)
                    .accessibilityIdentifier("reference.detail.visible")
            }
        } else {
            ContentUnavailableView(
                "Select an item",
                systemImage: "hand.tap",
                description: Text("Tap a table item to see its details here.")
            )
            .accessibilityIdentifier("reference.detail.empty")
        }
    }
}

/// Reuses the same domain detail views for the compact sheet and expanded pane.
struct ReferenceSelectedDetail: View {
    let item: ReferenceItem
    let onPractice: (ReferenceItem) -> Void
    @Environment(\.thaiData) private var thaiData
    @Environment(\.flashcardSettings) private var settings

    /// Judged on the chapter scope alone, even while searching: search can
    /// surface items beyond the chapter, and Practice should say so.
    private var isOutsideChapter: Bool {
        guard let settings else { return false }
        return !ReferenceBookScope(settings: settings, map: thaiData.bookChapters).includes(item, data: thaiData)
    }

    var body: some View {
        detail
            .environment(\.practiceIsOutsideChapter, isOutsideChapter)
    }

    private func practice() { onPractice(item) }

    @ViewBuilder
    private var detail: some View {
        switch item {
        case .consonant(let id):
            if let consonant = thaiData.consonants.first(where: { $0.id == id }) {
                ConsonantDetailSheet(consonant: consonant, onPractice: practice)
            }
        case .vowel(let id, let variant, let text):
            if let vowel = thaiData.vowels.first(where: { $0.id == id }) {
                VowelDetailSheet(vowel: vowel, formType: variant, text: text, onPractice: practice)
            }
        case .toneMark(let id, let soundKey):
            if let mark = thaiData.toneMarks.first(where: { $0.id == id }) {
                ToneMarkDetailSheet(toneMark: mark, soundKey: soundKey, onPractice: practice)
            }
        case .toneRule(let id):
            if let rule = thaiData.toneRules.first(where: { $0.id == id }) {
                ToneRuleDetailSheet(rule: rule, onPractice: practice)
            }
        case .cluster(let id):
            if let cluster = thaiData.clusters.first(where: { $0.id == id }) {
                ClusterDetailSheet(cluster: cluster) { _ in practice() }
            }
        }
    }
}

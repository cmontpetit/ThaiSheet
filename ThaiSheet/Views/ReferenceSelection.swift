import SwiftUI

/// Identifies the exact table cell, separately from the row's shared reading.
/// Vowel forms share concealment; tone-mark class columns do not.
enum ReferenceItem: Equatable, Identifiable {
    case consonant(String)
    case vowel(id: String, variant: VowelFormVariant, text: String)
    case toneMark(id: String, soundKey: String)
    case toneRule(String)
    case cluster(String)

    var id: String {
        switch self {
        case .vowel(let id, let variant, _):
            return "vowel-\(id):\(variant.duration.rawValue):\(variant.form.rawValue)"
        default:
            return concealID
        }
    }

    var concealID: String {
        switch self {
        case .consonant(let id): return FlashcardType.consonant.cardId(for: id)
        case .vowel(let id, _, _): return FlashcardType.vowel.cardId(for: id)
        case .toneMark(_, let soundKey): return FlashcardType.toneMark.cardId(for: soundKey)
        case .toneRule(let id): return FlashcardType.toneRule.cardId(for: id)
        case .cluster(let id): return FlashcardType.cluster.cardId(for: id)
        }
    }
}

/// Owns detail presentation independently of table rows and their lifetimes.
@Observable
final class ReferenceSelection {
    private(set) var item: ReferenceItem?
    private(set) var isExpanded = false
    private(set) var wantsSheet = false
    private(set) var hasMeasuredContainer = false
    private(set) var isReferenceActive = true
    private var awaitsReturnMeasurement = false
    /// A compact Show details action ends search before its sheet opens.
    private(set) var explicitSheetRequestID: UUID?

    var isSheetPresented: Bool {
        hasMeasuredContainer && wantsSheet && !isExpanded
    }

    func showDetails(_ item: ReferenceItem) {
        self.item = item
        wantsSheet = !isExpanded
        if !isExpanded { explicitSheetRequestID = UUID() }
    }

    func selectFromTap(_ item: ReferenceItem) {
        guard isExpanded else { return }
        showDetails(item)
    }

    func setReferenceActive(_ active: Bool) {
        guard active != isReferenceActive else { return }
        isReferenceActive = active
        if !active {
            // Preserve the exact selected cell, but returning to a tab must not
            // replay an automatic popup requested while that tab was hidden.
            wantsSheet = false
            explicitSheetRequestID = nil
            awaitsReturnMeasurement = true
        }
    }

    func setExpanded(
        _ expanded: Bool,
        readingIsConcealed: Bool = false,
        allowsAutomaticSheet: Bool = true
    ) {
        let canOpenAutomatically = isReferenceActive && !awaitsReturnMeasurement && allowsAutomaticSheet
        // Consume the return measurement even if the layout did not change.
        // Later folds while Reference is visible still hand off to a sheet.
        if isReferenceActive { awaitsReturnMeasurement = false }
        guard !hasMeasuredContainer || expanded != isExpanded else { return }
        hasMeasuredContainer = true
        isExpanded = expanded
        // Keep the selection even when concealment or an active search prevents
        // automatic presentation. Narrowing alone must not reveal an answer.
        wantsSheet = !expanded && item != nil && !readingIsConcealed && canOpenAutomatically
        explicitSheetRequestID = nil
    }

    func dismissSheet() {
        // SwiftUI also dismisses the sheet when it moves into the inline pane.
        // That callback must not discard the selection or a later compact sheet.
        guard !isExpanded else { return }
        wantsSheet = false
        explicitSheetRequestID = nil
    }

    func clear() {
        item = nil
        wantsSheet = false
        explicitSheetRequestID = nil
    }
}

private struct ReferenceSelectionKey: EnvironmentKey {
    static let defaultValue: ReferenceSelection? = nil
}

enum ReferenceDetailPlacement {
    case sheet, inline
}

private struct ReferenceDetailPlacementKey: EnvironmentKey {
    static let defaultValue = ReferenceDetailPlacement.sheet
}

extension EnvironmentValues {
    var referenceSelection: ReferenceSelection? {
        get { self[ReferenceSelectionKey.self] }
        set { self[ReferenceSelectionKey.self] = newValue }
    }

    var referenceDetailPlacement: ReferenceDetailPlacement {
        get { self[ReferenceDetailPlacementKey.self] }
        set { self[ReferenceDetailPlacementKey.self] = newValue }
    }
}

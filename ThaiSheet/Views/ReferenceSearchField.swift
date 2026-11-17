import SwiftUI
import UIKit

/// One persistent native field for the query that filters every Reference
/// section. Its text does not depend on navigation-bar search presentation.
struct ReferenceSearchField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Environment(\.locale) private var locale

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = context.coordinator
        let field = searchBar.searchTextField
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .search
        searchBar.enablesReturnKeyAutomatically = false
        field.clearButtonMode = .always
        context.coordinator.searchBar = searchBar
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        field.accessibilityIdentifier = "reference.search"
        searchBar.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchBar.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return searchBar
    }

    func updateUIView(_ searchBar: UISearchBar, context: Context) {
        context.coordinator.parent = self
        let field = searchBar.searchTextField
        searchBar.placeholder = String(localized: "Thai character or sound (e.g. kh)", bundle: .appLanguage, locale: locale)
        searchBar.setShowsCancelButton(isFocused, animated: false)
        // Never replace an unfinished Thai IME composition during a layout or
        // focus update. Editing events already keep the filtering query current.
        if field.text != text && field.markedTextRange == nil {
            field.text = text
        }
        context.coordinator.updateFocus(field)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    static func dismantleUIView(_ searchBar: UISearchBar, coordinator: Coordinator) {
        coordinator.removeOutsideTap()
        searchBar.delegate = nil
        coordinator.searchBar = nil
        searchBar.searchTextField.removeTarget(coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
    }

    final class Coordinator: NSObject, UISearchBarDelegate, UIGestureRecognizerDelegate {
        var parent: ReferenceSearchField
        weak var searchBar: UISearchBar?
        private var outsideTap: UITapGestureRecognizer?

        init(parent: ReferenceSearchField) { self.parent = parent }

        @objc func textChanged(_ field: UISearchTextField) {
            let text = field.text ?? ""
            if parent.text != text { parent.text = text }
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            textChanged(searchBar.searchTextField)
        }

        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            installOutsideTap(in: searchBar.window)
            searchBar.setShowsCancelButton(true, animated: true)
            if !parent.isFocused { parent.isFocused = true }
        }

        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            removeOutsideTap()
            textChanged(searchBar.searchTextField)
            searchBar.setShowsCancelButton(false, animated: true)
            if parent.isFocused { parent.isFocused = false }
        }

        func finishEditing() {
            // End focus as well as hiding the keyboard so a later SwiftUI
            // update cannot restore editing. The filtering query is unchanged.
            if let field = searchBar?.searchTextField {
                field.unmarkText()
                textChanged(field)
            }
            parent.isFocused = false
            searchBar?.searchTextField.resignFirstResponder()
        }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            finishEditing()
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            finishEditing()
        }

        private func installOutsideTap(in window: UIWindow?) {
            removeOutsideTap()
            guard let window else { return }
            let tap = UITapGestureRecognizer(target: self, action: #selector(tappedOutside))
            tap.name = "reference.search.dismissOutside"
            // Observe the tap alongside controls and SwiftUI row gestures.
            // The same tap must still play/select a row or activate a button.
            tap.cancelsTouchesInView = false
            tap.delaysTouchesBegan = false
            tap.delaysTouchesEnded = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            outsideTap = tap
        }

        func removeOutsideTap() {
            if let tap = outsideTap { tap.view?.removeGestureRecognizer(tap) }
            outsideTap = nil
        }

        @objc func tappedOutside() {
            guard searchBar?.searchTextField.isFirstResponder == true else { return }
            finishEditing()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let searchBar, searchBar.searchTextField.isFirstResponder,
                  let view = touch.view else { return false }
            // Editing, clearing, and the native cancel control belong to the
            // search bar. Keyboard touches must keep editing too.
            if view.isDescendant(of: searchBar) { return false }
            if let keyboard = searchBar.searchTextField.inputView,
               view.isDescendant(of: keyboard) { return false }
            return view.window === searchBar.window
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func updateFocus(_ field: UISearchTextField) {
            let wantsFocus = parent.isFocused
            guard field.isFirstResponder != wantsFocus else { return }
            // Focus callbacks update SwiftUI state; deliver them after this
            // representable update, when the field has joined its window.
            DispatchQueue.main.async { [weak self, weak field] in
                guard let self, let field, field.window != nil,
                      self.parent.isFocused == wantsFocus else { return }
                if wantsFocus {
                    field.becomeFirstResponder()
                } else {
                    field.resignFirstResponder()
                }
            }
        }
    }
}

import SwiftUI
import UIKit

/// One persistent native field for the query that filters every Reference
/// section. Its text does not depend on navigation-bar search presentation.
struct ReferenceSearchField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Environment(\.locale) private var locale

    func makeUIView(context: Context) -> UISearchTextField {
        let field = UISearchTextField(frame: .zero)
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .search
        field.clearButtonMode = .always
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        field.accessibilityIdentifier = "reference.search"
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UISearchTextField, context: Context) {
        context.coordinator.parent = self
        field.placeholder = String(localized: "Thai character or sound (e.g. kh)", bundle: .appLanguage, locale: locale)
        // Never replace an unfinished Thai IME composition during a layout or
        // focus update. Editing events already keep the filtering query current.
        if field.text != text && field.markedTextRange == nil {
            field.text = text
        }
        context.coordinator.updateFocus(field)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    static func dismantleUIView(_ field: UISearchTextField, coordinator: Coordinator) {
        field.delegate = nil
        field.removeTarget(coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ReferenceSearchField

        init(parent: ReferenceSearchField) { self.parent = parent }

        @objc func textChanged(_ field: UISearchTextField) {
            let text = field.text ?? ""
            if parent.text != text { parent.text = text }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isFocused { parent.isFocused = false }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
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

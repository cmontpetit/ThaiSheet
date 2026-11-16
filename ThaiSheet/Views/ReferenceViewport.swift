import SwiftUI
import UIKit

/// A live measurement outside the tabs. A returning tab's own GeometryReaders
/// can still describe its old layout, so presentation decisions read these
/// current owning controller bounds rather than counting child layout passes.
@MainActor
final class ReferenceViewport {
    fileprivate weak var controller: UIViewController?

    var size: CGSize? {
        guard let owner = controller?.parent, owner.isViewLoaded,
              owner.view.window != nil else { return nil }
        let size = owner.view.bounds.size
        guard size.width > 0, size.height > 0 else { return nil }
        return size
    }
}

private struct ReferenceViewportKey: EnvironmentKey {
    static let defaultValue: ReferenceViewport? = nil
}

extension EnvironmentValues {
    var referenceViewport: ReferenceViewport? {
        get { self[ReferenceViewportKey.self] }
        set { self[ReferenceViewportKey.self] = newValue }
    }
}

extension View {
    /// Place this outside TabView so the measurement keeps receiving layout
    /// while another tab is selected. Controller bounds stay independent of
    /// keyboard safe-area and navigation-bar inset updates.
    func referenceViewportScope() -> some View {
        modifier(ReferenceViewportScope())
    }
}

private struct ReferenceViewportScope: ViewModifier {
    @State private var viewport = ReferenceViewport()

    func body(content: Content) -> some View {
        content
            .background {
                ReferenceViewportProbe(viewport: viewport)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .environment(\.referenceViewport, viewport)
    }
}

private struct ReferenceViewportProbe: UIViewControllerRepresentable {
    let viewport: ReferenceViewport

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        viewport.controller = controller
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        viewport.controller = controller
    }
}

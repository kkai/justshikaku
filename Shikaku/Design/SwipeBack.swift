import SwiftUI

/// Turns off the interactive pop gesture on a screen the player drags across.
///
/// Shikaku is entirely drag-driven, and now that the room runs to the screen
/// edges a left-to-right drag that starts in the first column is exactly the
/// gesture UIKit reads as "go back" — so laying a mat along the left wall
/// could throw the player out of the puzzle. Ported from the sibling that
/// wrote this for the same reason (`Hashi/Design/PlatformSeams.swift`).
#if os(iOS)
struct SwipeBackDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        /// What the gesture was set to before this screen touched it, so the
        /// restore puts back the real previous value rather than assuming true.
        private var wasEnabled: Bool?

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let gesture = navigationController?.interactivePopGestureRecognizer else { return }
            wasEnabled = gesture.isEnabled
            gesture.isEnabled = false
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if let wasEnabled {
                navigationController?.interactivePopGestureRecognizer?.isEnabled = wasEnabled
            }
            wasEnabled = nil
        }
    }
}
#endif

extension View {
    /// Turns off the interactive pop gesture while this screen is showing.
    /// Use it on anything the player drags across.
    @ViewBuilder
    func swipeBackDisabled() -> some View {
        #if os(iOS)
        background(SwipeBackDisabler().frame(width: 0, height: 0).accessibilityHidden(true))
        #else
        self
        #endif
    }
}

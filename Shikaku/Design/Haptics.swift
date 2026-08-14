import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Haptic vocabulary. Intensity scales with rarity, and only the rarest event
/// that just happened speaks: a win silences the mat settle, which silences
/// the preview tick. `@MainActor` and it must stay so — UIFeedbackGenerator
/// is NS_SWIFT_UI_ACTOR and `enabled` is mutable global state.
@MainActor
enum Haptics {

    /// Applied from settings at launch AND when the toggle changes — applying
    /// it only on change is how a setting ends up doing nothing.
    static var enabled = true

    #if canImport(UIKit)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let notification = UINotificationFeedbackGenerator()
    #endif

    /// The preview growing or shrinking by a cell.
    static func previewTick() {
        #if canImport(UIKit)
        guard enabled else { return }
        light.impactOccurred(intensity: 0.4)
        #endif
    }

    /// A mat settling into the floor.
    static func matSettle() {
        #if canImport(UIKit)
        guard enabled else { return }
        medium.impactOccurred(intensity: 0.7)
        #endif
    }

    /// A mat lifted back off the board.
    static func matRemove() {
        #if canImport(UIKit)
        guard enabled else { return }
        light.impactOccurred(intensity: 0.55)
        #endif
    }

    /// A rejected drag (zero or two clues swept).
    static func reject() {
        #if canImport(UIKit)
        guard enabled else { return }
        notification.notificationOccurred(.warning)
        #endif
    }

    /// The only `.success` in the app: the room is finished.
    static func win() {
        #if canImport(UIKit)
        guard enabled else { return }
        notification.notificationOccurred(.success)
        #endif
    }
}

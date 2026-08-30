import SwiftUI

/// Radius, spacing, and button vocabulary. One scale, or the app grows five
/// corner radii and fourteen button treatments (a sibling measured exactly
/// that).
///
/// **Nothing on this floor is rounded.** The roundness budget used to be
/// spent on cards and sheets; those are gone (see `AnnotationRail`), and a
/// rounded control sitting next to a square mat, a square seal and a square
/// timber frame was the last thing on screen that still looked like a stock
/// iOS app. `controlRadius` stays at zero rather than being deleted so the
/// decision is visible and reversible in one place.
///
/// `nonisolated` for the same reason as `Theme`.
nonisolated enum Layout {

    // 4pt spacing scale.
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 24
    static let s6: CGFloat = 32

    // Radius scale.
    static let controlRadius: CGFloat = 0
    static let cardRadius: CGFloat = 12
    static let sheetRadius: CGFloat = 16
}

nonisolated struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.floor)
            .padding(.vertical, Layout.s3)
            .frame(maxWidth: .infinity)
            .background(Theme.ink, in: Rectangle())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

nonisolated struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.ink)
            .padding(.vertical, Layout.s3)
            .frame(maxWidth: .infinity)
            .background(
                Rectangle()
                    .strokeBorder(Theme.hairline, lineWidth: 1)
                    .background(Theme.frame, in: Rectangle())
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

nonisolated struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.inkSoft)
            .padding(.vertical, Layout.s2)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

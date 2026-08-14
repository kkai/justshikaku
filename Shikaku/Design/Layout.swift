import SwiftUI

/// Radius, spacing, and button vocabulary. One scale, or the app grows five
/// corner radii and fourteen button treatments (a sibling measured exactly
/// that). Mats are square-cornered on purpose — the roundness budget is spent
/// on cards and sheets only.
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
    static let controlRadius: CGFloat = 8
    static let cardRadius: CGFloat = 12
    static let sheetRadius: CGFloat = 16
}

nonisolated struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.surface)
            .padding(.vertical, Layout.s3)
            .frame(maxWidth: .infinity)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: Layout.controlRadius))
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
                RoundedRectangle(cornerRadius: Layout.controlRadius)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Layout.controlRadius))
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

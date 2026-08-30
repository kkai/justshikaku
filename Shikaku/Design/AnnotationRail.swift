import SwiftUI

/// Prose that belongs to the board, drawn as an annotation on the plan rather
/// than floated in a rounded card.
///
/// The white `Theme.surface` card at `Layout.cardRadius` was the most
/// anonymous element in the app — and it was the container carrying the hint
/// text, which is the one thing no competitor's board can say. A full-bleed
/// rule and a margin mark say it in the drawing's own vocabulary and cost
/// nothing in legibility.
///
/// `marked` draws the vermilion callout bar: the app is teaching right now.
/// It is one of the only two places `Theme.shu` is allowed to appear at once.
struct AnnotationRail<Content: View>: View {
    var marked: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(marked ? Theme.shu : Color.clear)
                .frame(width: 2)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Layout.s4)
                .padding(.vertical, Layout.s3)
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
        }
    }
}

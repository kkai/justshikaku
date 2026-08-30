import SwiftUI

/// "Just Shikaku" with the drag-diagonal struck through "Shikaku".
///
/// The construction is the family's (Kakuro strikes its clue-cell diagonal
/// through the K; Hashi draws islands and a bridge): a `ViewThatFits` ladder
/// of whole lockups, so the dash and the type always scale together. The
/// voice is Shikaku's own — bold grotesque where Kakuro is serif and Hashi
/// is rounded — and the dash is the game's own gesture: a rectangle here is
/// defined by dragging its diagonal, so the diagonal wears a small square
/// tick at each end, like the drag's anchor and head.
struct Wordmark: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                lockup(fontSize: 40)
                lockup(fontSize: 34)
                lockup(fontSize: 28)
            }
            Text("Divide the room into rectangles.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func lockup(fontSize: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text(verbatim: "Just")
                .padding(.trailing, fontSize * 0.24)
            Text(verbatim: "Shikaku")
                .overlay {
                    DragDiagonal()
                        .stroke(Theme.heri,
                                style: StrokeStyle(lineWidth: fontSize / 16, lineCap: .round))
                        .overlay(alignment: .topTrailing) { tick(fontSize) }
                        .overlay(alignment: .bottomLeading) { tick(fontSize) }
                        .padding(.horizontal, -fontSize * 0.06)
                        .padding(.vertical, fontSize * 0.14)
                }
        }
        .font(.system(size: fontSize, weight: .bold))
        .foregroundStyle(Theme.ink)
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Just Shikaku")
    }

    /// The drag's anchor/head: a small filled square, like a laid cell.
    private func tick(_ fontSize: CGFloat) -> some View {
        Rectangle()
            .fill(Theme.heri)
            .frame(width: fontSize * 0.14, height: fontSize * 0.14)
    }
}

/// Bottom-leading to top-trailing — the direction of laying a mat.
private struct DragDiagonal: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

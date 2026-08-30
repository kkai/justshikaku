import SwiftUI

/// The wordmark's glyph: a square partitioned into rectangles, with one of
/// them laid.
///
/// It is the game's own move, drawn once — the same idea the icon states with
/// a single lit mat in a lacquered room. Siblings do this too (Kakuro strikes
/// a clue-cell diagonal through its K, Hashi draws two islands and a bridge);
/// what is copied is the *technique* of a wordmark that performs the game,
/// never the layout it sits in.
nonisolated struct ShikakuMark: View {
    var side: CGFloat
    var line: CGFloat = 2

    var body: some View {
        let u = side / 3
        // An outer border with two interior cuts — one vertical at 1/3, one
        // horizontal across the right column — and the bottom-right 2×2 laid.
        // Reads as a partitioned room rather than a sidebar glyph: the cuts
        // are lines through a frame, not three separate boxes.
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Theme.ink)
                .frame(width: u * 2 + line / 2, height: u * 2 + line / 2)
                .offset(x: u - line / 4, y: u - line / 4)
            Rectangle()
                .strokeBorder(Theme.ink, lineWidth: line)
            Rectangle()
                .fill(Theme.ink)
                .frame(width: line, height: side)
                .offset(x: u - line / 2)
            Rectangle()
                .fill(Theme.ink)
                .frame(width: side - u, height: line)
                .offset(x: u, y: u - line / 2)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

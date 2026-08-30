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
    var line: CGFloat = 1.5

    var body: some View {
        let u = side / 3
        ZStack(alignment: .topLeading) {
            // A 1×3 strip down the left.
            Rectangle()
                .strokeBorder(Theme.ink, lineWidth: line)
                .frame(width: u, height: side)
            // A 2×1 across the top right.
            Rectangle()
                .strokeBorder(Theme.ink, lineWidth: line)
                .frame(width: u * 2, height: u)
                .offset(x: u)
            // The laid mat: the one rectangle that is finished.
            Rectangle()
                .fill(Theme.ink)
                .frame(width: u * 2, height: u * 2)
                .offset(x: u, y: u)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

import SwiftUI

/// The board's own digits.
///
/// Kakuro speaks New York serif, Hashi speaks rounded — Shikaku's digits are
/// drawn, not typeset: squarish strokes on a plan grid, every corner a hard
/// corner, like numbers scratched into a floor plan. They appear **only on
/// the board** (clue values, the have/need tag); all chrome stays SF.
///
/// Each glyph is a set of strokes on a 12×20 design grid, rendered as one
/// stroked path so the weight scales with the cell. The seven-segment
/// skeleton is deliberately bent in a few places (the open 4, the angled 7,
/// the tailed 6 and 9) so it reads as drawn rather than as an LCD.
nonisolated struct NumeralShape: Shape {
    let digit: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 12
        let sy = rect.height / 20
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        func stroke(_ points: [(CGFloat, CGFloat)]) {
            guard let first = points.first else { return }
            path.move(to: p(first.0, first.1))
            for point in points.dropFirst() {
                path.addLine(to: p(point.0, point.1))
            }
        }
        switch ((digit % 10) + 10) % 10 {
        case 0:
            stroke([(1, 1), (11, 1), (11, 19), (1, 19), (1, 1)])
            stroke([(1, 1), (11, 19)])                      // the plan's diagonal
        case 1:
            stroke([(3, 4), (7, 1), (7, 19)])
            stroke([(2, 19), (11, 19)])
        case 2:
            stroke([(1, 4), (1, 1), (11, 1), (11, 9), (1, 9), (1, 19), (11, 19)])
        case 3:
            stroke([(1, 1), (11, 1), (11, 19), (1, 19)])
            stroke([(4, 9), (11, 9)])
        case 4:
            stroke([(8, 19), (8, 1), (1, 12), (11, 12)])
        case 5:
            stroke([(11, 1), (1, 1), (1, 9), (11, 9), (11, 19), (1, 19), (1, 16)])
        case 6:
            stroke([(10, 1), (1, 1), (1, 19), (11, 19), (11, 9), (1, 9)])
        case 7:
            stroke([(1, 4), (1, 1), (11, 1), (5, 19)])
        case 8:
            stroke([(1, 9), (1, 1), (11, 1), (11, 9), (1, 9), (1, 19), (11, 19), (11, 9)])
        default: // 9
            stroke([(11, 9), (1, 9), (1, 1), (11, 1), (11, 19), (2, 19)])
        }
        return path
    }
}

/// One drawn number, any value ≥ 0. Digit weight tracks the point size so a
/// 5×5 clue and a 12×12 clue read as the same hand.
struct Numeral: View {
    let value: Int
    var size: CGFloat
    var color: Color = Theme.ink
    /// Lighter stroke for a satisfied clue — the "relaxed" state the old
    /// font-weight switch expressed.
    var relaxed: Bool = false

    var body: some View {
        let digits = String(value).compactMap(\.wholeNumberValue)
        let digitWidth = size * 0.6
        let weight = max(size * (relaxed ? 0.075 : 0.11), 1.2)
        HStack(spacing: size * 0.18) {
            ForEach(Array(digits.enumerated()), id: \.offset) { _, digit in
                NumeralShape(digit: digit)
                    .stroke(color, style: StrokeStyle(
                        lineWidth: weight, lineCap: .square, lineJoin: .miter))
                    .frame(width: digitWidth, height: size)
            }
        }
        .accessibilityHidden(true)
    }
}

/// "have/need" as drawn digits with a cut slash.
struct NumeralFraction: View {
    let have: Int
    let need: Int
    var size: CGFloat
    var color: Color = Theme.ink

    var body: some View {
        HStack(spacing: size * 0.14) {
            Numeral(value: have, size: size, color: color)
            SlashGlyph()
                .stroke(color, style: StrokeStyle(lineWidth: max(size * 0.1, 1.2),
                                                  lineCap: .square))
                .frame(width: size * 0.5, height: size)
            Numeral(value: need, size: size, color: color)
        }
        .accessibilityHidden(true)
    }
}

private nonisolated struct SlashGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.05))
        return path
    }
}

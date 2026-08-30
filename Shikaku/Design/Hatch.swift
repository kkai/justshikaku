import SwiftUI

/// Ruling something out is **drawn, not coloured**.
///
/// An eliminated placement, a wrong mat, a cell a drag cannot have: all of
/// them get hatched over, the way a carpenter crosses a measurement off a
/// plan. That is what frees `Theme.shu` to mean one thing only — the app is
/// teaching you something — instead of doing double duty as an error colour.
///
/// The lines carry a small wobble so the fill reads as ruled by hand rather
/// than generated. It is deterministic, not random: `path(in:)` is called
/// again on every layout pass, and jitter that changed between calls would
/// shimmer during a drag.
nonisolated struct HatchShape: Shape {
    /// Distance between lines, in points. Small rects need a tighter pitch or
    /// they get one lonely diagonal.
    var pitch: CGFloat = 7
    /// Hatch direction. A single direction reads as "ruled out"; crossing two
    /// passes reads as "ruled out everywhere", which the argument overlay uses
    /// for a placement no candidate can occupy.
    var rising: Bool = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard pitch > 0, rect.width > 0, rect.height > 0 else { return path }

        // Walk the diagonal family across the rect's full extent: a 45° line
        // entering at x needs to travel `rect.height` horizontally to clear
        // the box, so the sweep starts one height early.
        var offset: CGFloat = -rect.height
        var index = 0
        while offset <= rect.width + rect.height {
            let d = offset + Self.wobble(index)
            if rising {
                path.move(to: CGPoint(x: rect.minX + d, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX + d + rect.height, y: rect.minY))
            } else {
                path.move(to: CGPoint(x: rect.minX + d, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX + d + rect.height, y: rect.maxY))
            }
            offset += pitch
            index += 1
        }
        return path
    }

    /// A cheap deterministic hash into roughly ±0.9pt — enough to break the
    /// mechanical regularity, not enough to read as a mistake.
    private static func wobble(_ i: Int) -> CGFloat {
        let h = UInt32(truncatingIfNeeded: i) &* 2_654_435_761
        return CGFloat(h % 1000) / 1000 * 1.8 - 0.9
    }
}

/// Hatching sized to fill whatever it is placed in, clipped to its own bounds.
///
/// `HatchShape`'s lines deliberately overshoot the rect so the diagonals reach
/// the corners; the clip is what turns that into a fill, so callers should not
/// have to remember it.
nonisolated struct Hatching: View {
    var pitch: CGFloat = 7
    var lineWidth: CGFloat = 1
    var color: Color = Theme.hatch
    /// Cross-hatch: two passes at opposing angles.
    var crossed: Bool = false

    var body: some View {
        ZStack {
            HatchShape(pitch: pitch, rising: true)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            if crossed {
                HatchShape(pitch: pitch, rising: false)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
        }
        .clipShape(Rectangle())
        .allowsHitTesting(false)
    }
}

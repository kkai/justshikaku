//
//  BoardView.swift
//  Shikaku
//
//  The board: one absolutely-positioned layer stack against BoardGeometry —
//  lattice → mats → clue numerals → drag preview. Deliberately split into
//  small views with explicitly-typed intermediates: three sibling views hit
//  "unable to type-check this expression in reasonable time" and the fix is
//  documented in docs/ENGINEERING.md. Do not re-inline.
//

import SwiftUI

struct BoardView: View {
    let game: ShikakuGame
    /// How far beyond the lattice touches still count, in points. RoomBoard
    /// sets this to its timber band so a drag that starts on the wood clamps
    /// into the border row/column instead of dying — border cells are the
    /// category's sore spot, and the frame is forgiving, not dead.
    var touchOutset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let geo = BoardGeometry(size: game.puzzle.size, container: proxy.size)
            ZStack(alignment: .topLeading) {
                LatticeView(geo: geo)
                MatsLayer(game: game, geo: geo)
                CluesLayer(game: game, geo: geo)
                PreviewLayer(game: game, geo: geo)
                if let hint = game.activeHint {
                    ArgumentOverlay(hint: hint, geo: geo, puzzle: game.puzzle)
                }
            }
            .contentShape(Rectangle().inset(by: -touchOutset))
            .gesture(dragGesture(geo: geo))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func dragGesture(geo: BoardGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Anchor from startLocation, not the first onChanged location:
                // a fast flick's first event can arrive already at the
                // endpoint, which would collapse the drag into a tap.
                game.dragChanged(
                    anchor: geo.clampedCell(at: value.startLocation),
                    current: geo.clampedCell(at: value.location))
            }
            .onEnded { _ in
                game.dragEnded()
            }
    }
}

// MARK: - Lattice

/// Graph paper on straw: fine hairlines with dots at the intersections —
/// a plan awaiting a room. Committed mats visually replace it inside their
/// bounds.
private struct LatticeView: View {
    let geo: BoardGeometry

    var body: some View {
        let lines = LatticeShape(geo: geo)
        let dots = LatticeDots(geo: geo)
        ZStack(alignment: .topLeading) {
            lines.stroke(Theme.hairline, lineWidth: 1)
            dots.fill(Theme.hairline)
        }
    }
}

private struct LatticeShape: Shape {
    let geo: BoardGeometry

    func path(in _: CGRect) -> Path {
        var path = Path()
        let n = geo.size
        for i in 0...n {
            let x = geo.origin.x + CGFloat(i) * geo.cellSize
            path.move(to: CGPoint(x: x, y: geo.origin.y))
            path.addLine(to: CGPoint(x: x, y: geo.origin.y + geo.boardLength))
            let y = geo.origin.y + CGFloat(i) * geo.cellSize
            path.move(to: CGPoint(x: geo.origin.x, y: y))
            path.addLine(to: CGPoint(x: geo.origin.x + geo.boardLength, y: y))
        }
        return path
    }
}

private struct LatticeDots: Shape {
    let geo: BoardGeometry

    func path(in _: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = 1.6
        for row in 0...geo.size {
            for col in 0...geo.size {
                let x = geo.origin.x + CGFloat(col) * geo.cellSize
                let y = geo.origin.y + CGFloat(row) * geo.cellSize
                path.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
            }
        }
        return path
    }
}

// MARK: - Mats

private struct MatsLayer: View {
    let game: ShikakuGame
    let geo: BoardGeometry

    var body: some View {
        ForEach(game.board.placed, id: \.self) { placed in
            MatView(placed: placed, game: game, geo: geo)
        }
        ClaimsLayer(game: game, geo: geo)
    }
}

/// One committed mat: opaque igusa fill, heri edge band, a weave running
/// along the long axis (real tatami alternate weave direction — orientation
/// is encoded, not decorated; squares get no weave), and a have/need tag when
/// the area disagrees with the clue. A conflicting mat is hatched over, not
/// reddened: in this app red means the app is teaching, and nothing else.
private struct MatView: View {
    let placed: PlacedRect
    let game: ShikakuGame
    let geo: BoardGeometry

    @State private var settled = false
    /// One beat of vermilion on the edge as the mat lands — the snap of the
    /// sumitsubo line. Decays to the heri band under Motion.stringSnap.
    @State private var snapping = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        let frame: CGRect = geo.rect(for: placed.rect)
        // A rule-level conflict (wrong area) always shows; a solution-level
        // mistake shows only when the player asked to see mistakes — those
        // are the locally-legal wrong mats that let a player drift.
        let conflict: Bool = game.areaConflict(placed)
            || (progress.settings.errorFeedback && game.isWrong(placed))
        // Bottom-trailing, not top-trailing: the clue numeral sits in the
        // middle of its cell, and on a two-cell mat a top-corner tag lands on
        // top of it.
        ZStack(alignment: .bottomTrailing) {
            matBody(frame: frame, conflict: conflict)
            // The have/need tag belongs to area conflicts only — a
            // solution-level mistake has the right count, just the wrong home.
            if game.areaConflict(placed) {
                conflictBadge
                    .padding(4)
            }
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
        .scaleEffect(settled || reduceMotion ? 1.0 : 1.02)
        .shadow(color: .black.opacity(settled || reduceMotion ? 0 : 0.18), radius: 6, y: 2)
        .onAppear {
            withAnimation(reduceMotion ? nil : Motion.settle) { settled = true }
            withAnimation(reduceMotion ? nil : Motion.stringSnap) { snapping = false }
        }
        .accessibilityElement()
        .accessibilityLabel(matAccessibilityLabel(conflict: conflict))
    }

    @ViewBuilder
    private func matBody(frame: CGRect, conflict: Bool) -> some View {
        let weave = WeaveShape(horizontal: placed.rect.width >= placed.rect.height,
                               isSquare: placed.rect.width == placed.rect.height)
        Rectangle()
            .fill(Theme.mat)
            .overlay(weave.stroke(Theme.heri.opacity(0.22), lineWidth: 1))
            .overlay(matInnerShadow)
            .overlay(
                Rectangle()
                    .strokeBorder(snapping && !reduceMotion ? Theme.shu : Theme.heri,
                                  lineWidth: 1.5)
            )
            // A mat whose area does not match its clue is hatched over rather
            // than outlined in red: eliminations are drawn in this app. The
            // hatch goes dark here — bone-on-igusa reads as woven texture,
            // which is the one thing this mark must not look like.
            .overlay {
                if conflict {
                    Hatching(pitch: 6, lineWidth: 1.25, color: .black.opacity(0.5))
                }
            }
            // The grout gap. Insetting each mat leaves a seam of floor between
            // neighbours, so two adjacent rectangles read as two laid objects
            // instead of one green region — which is both the material point
            // and, on a crowded board, genuinely easier to parse.
            .padding(1.5)
    }

    /// Mats sit *in* the room rather than on it. A one-stop gradient at each
    /// edge is enough — a real inner shadow would need a mask per mat, and at
    /// these sizes it would not read.
    private var matInnerShadow: some View {
        LinearGradient(colors: [.black.opacity(0.22), .clear],
                       startPoint: .top, endPoint: .bottom)
            .blendMode(.multiply)
            .allowsHitTesting(false)
    }

    private var conflictBadge: some View {
        let need: Int = game.puzzle.clues[placed.clueIndex].value
        return NumeralFraction(have: placed.rect.area, need: need,
                               size: geo.badgeSize * 0.8)
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .background(Theme.floor.opacity(0.92), in: Rectangle())
    }

    private func matAccessibilityLabel(conflict: Bool) -> String {
        let value = game.puzzle.clues[placed.clueIndex].value
        let shape = "\(placed.rect.width) by \(placed.rect.height)"
        return conflict
            ? "Mat \(shape), holds \(placed.rect.area) cells but its clue needs \(value)"
            : "Mat \(shape) for the \(value)"
    }
}

/// Weave stripes along the long axis, clipped by the mat that overlays this.
private struct WeaveShape: Shape {
    let horizontal: Bool
    let isSquare: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !isSquare else { return path }
        let pitch: CGFloat = 6
        if horizontal {
            var y = rect.minY + pitch
            while y < rect.maxY {
                path.move(to: CGPoint(x: rect.minX + 2, y: y))
                path.addLine(to: CGPoint(x: rect.maxX - 2, y: y))
                y += pitch
            }
        } else {
            var x = rect.minX + pitch
            while x < rect.maxX {
                path.move(to: CGPoint(x: x, y: rect.minY + 2))
                path.addLine(to: CGPoint(x: x, y: rect.maxY - 2))
                x += pitch
            }
        }
        return path
    }
}

/// Hint-applied claim marks: a small heri dot in the cell's corner saying
/// "this cell belongs to that clue" — how elimination-only hint steps
/// visibly apply.
private struct ClaimsLayer: View {
    let game: ShikakuGame
    let geo: BoardGeometry

    var body: some View {
        let claims: [(Cell, Int)] = game.board.claims.sorted { $0.key < $1.key }
        ForEach(claims, id: \.0) { cell, _ in
            let frame: CGRect = geo.rect(for: cell)
            Circle()
                .fill(Theme.heri)
                .frame(width: 5, height: 5)
                .position(x: frame.minX + 7, y: frame.minY + 7)
        }
    }
}

// MARK: - Clues

private struct CluesLayer: View {
    let game: ShikakuGame
    let geo: BoardGeometry

    var body: some View {
        let satisfied: [Bool] = game.isClueSatisfied
        ForEach(Array(game.puzzle.clues.enumerated()), id: \.offset) { index, clue in
            ClueNumeral(clue: clue, isSatisfied: satisfied[index], geo: geo)
        }
    }
}

/// A satisfied clue relaxes: lighter weight, still bone.
///
/// It used to switch to `Theme.heri`, which was legible on straw and is not
/// legible on an opaque igusa mat — the two greens sit about two stops apart.
/// The mat under the numeral already says "housed"; the weight change is the
/// only signal the colour needs to carry.
private struct ClueNumeral: View {
    let clue: Clue
    let isSatisfied: Bool
    let geo: BoardGeometry

    var body: some View {
        let center: CGPoint = geo.center(for: clue.cell)
        Numeral(value: clue.value, size: geo.clueSize, relaxed: isSatisfied)
            .position(center)
            .animation(Motion.chrome, value: isSatisfied)
            .accessibilityElement()
            .accessibilityLabel("Clue \(clue.value)\(isSatisfied ? ", housed" : "")")
    }
}

// MARK: - Drag preview

private struct PreviewLayer: View {
    let game: ShikakuGame
    let geo: BoardGeometry

    var body: some View {
        if let preview = game.preview {
            SnapLineView(preview: preview, game: game, geo: geo)
        }
        if let rejected = game.rejectedPreview {
            RejectedView(rect: rejected, geo: geo)
        }
    }
}

/// The sumitsubo line: a taut ink rectangle tracking the finger, with a live
/// area badge once exactly one clue is inside.
private struct SnapLineView: View {
    let preview: ShikakuGame.DragPreview
    let game: ShikakuGame
    let geo: BoardGeometry

    var body: some View {
        let frame: CGRect = geo.rect(for: preview.rect)
        ZStack(alignment: .topLeading) {
            conflictWash
            Rectangle()
                .fill(Theme.inkLine.opacity(0.05))
                .overlay(Rectangle().strokeBorder(Theme.inkLine, lineWidth: 2))
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .animation(Motion.snapLine, value: preview.rect)
            badge(frame: frame)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var conflictWash: some View {
        ForEach(preview.conflictCells, id: \.self) { cell in
            let f: CGRect = geo.rect(for: cell)
            Hatching(pitch: 5, lineWidth: 1)
                .frame(width: f.width, height: f.height)
                .position(x: f.midX, y: f.midY)
        }
    }

    @ViewBuilder
    private func badge(frame: CGRect) -> some View {
        if let clueIndex = preview.clueIndex {
            let need: Int = game.puzzle.clues[clueIndex].value
            let have: Int = preview.rect.area
            NumeralFraction(have: have, need: need, size: geo.badgeSize,
                            color: have == need ? Theme.heri : Theme.ink)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Theme.floor.opacity(0.92), in: Rectangle())
                .position(x: frame.midX, y: frame.minY - geo.badgeSize)
        }
    }
}

/// A rejected drag shakes off and evaporates.
private struct RejectedView: View {
    let rect: GridRect
    let geo: BoardGeometry

    @State private var shake = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let frame: CGRect = geo.rect(for: rect)
        Rectangle()
            .strokeBorder(Theme.hatch, lineWidth: 2)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .offset(x: shake || reduceMotion ? 0 : 5)
            .opacity(shake ? 0 : 0.9)
            .onAppear {
                withAnimation(reduceMotion ? Motion.chrome : Motion.matReject) { shake = true }
            }
            .allowsHitTesting(false)
    }
}

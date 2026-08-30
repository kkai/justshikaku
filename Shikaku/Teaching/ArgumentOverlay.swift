//
//  ArgumentOverlay.swift
//  Shikaku
//
//  The drawn argument: ghost rectangles for the placements under discussion,
//  struck ghosts for the ones that die, burn-in for claimed cells, a
//  spotlight for the focus cell. Eliminations strike SPECIFIC ghosts, never
//  a generic wash — the player must see which placements died (the family's
//  strike-the-glyphs lesson, in rectangle form).
//
//  Split into small views with typed intermediates — type-checker budget,
//  docs/ENGINEERING.md.
//

import SwiftUI

struct ArgumentOverlay: View {
    let hint: Hint
    let geo: BoardGeometry
    /// For the dimension arrows' origin — the protagonist clue's own cell.
    var puzzle: Puzzle? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            if hint.showsArgument, let step = hint.step {
                ArgumentBody(step: step, geo: geo, puzzle: puzzle)
                TechniqueLettering(technique: step.technique, geo: geo)
            }
            if hint.isError {
                ErrorMarks(hint: hint, geo: geo)
            }
            FocusMarks(cells: hint.focusCells, geo: geo)
        }
        .allowsHitTesting(false)
    }
}

/// The technique's name, lettered on the plan like a drawing annotation —
/// spaced capitals in the band above the lattice, never a floating card.
private struct TechniqueLettering: View {
    let technique: Technique
    let geo: BoardGeometry

    var body: some View {
        Text(TechniqueContent.name(for: technique).uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(2)
            .foregroundStyle(Theme.shu)
            .position(x: geo.boardRect.midX, y: geo.boardRect.minY - 12)
            .transition(.opacity)
            .accessibilityHidden(true)   // the hint banner reads the name out
    }
}

/// A dimension-drawing arrow: shaft with perpendicular end ticks, from the
/// protagonist clue to each claimed cell — the *reach* argument drawn the
/// way a plan dimensions a span.
private struct DimensionArrows: View {
    let step: SolverStep
    let geo: BoardGeometry
    let puzzle: Puzzle?

    var body: some View {
        if let puzzle,
           let clueIndex = step.explanation.clueIndices.first,
           puzzle.clues.indices.contains(clueIndex),
           step.technique == .mustCover || step.technique == .soleOwner {
            let origin: CGPoint = geo.center(for: puzzle.clues[clueIndex].cell)
            ForEach(Array(step.explanation.claimedCells.prefix(4).enumerated()),
                    id: \.offset) { _, cell in
                if cell != puzzle.clues[clueIndex].cell {
                    let target: CGPoint = geo.center(for: cell)
                    DimensionArrowShape(from: origin, to: target,
                                        tick: max(geo.cellSize * 0.14, 4))
                        .stroke(Theme.shu, style: StrokeStyle(lineWidth: 1.5, lineCap: .square))
                        .transition(.opacity)
                }
            }
        }
    }
}

private nonisolated struct DimensionArrowShape: Shape {
    let from: CGPoint
    let to: CGPoint
    let tick: CGFloat

    func path(in _: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        // Perpendicular ticks at both ends.
        let dx = to.x - from.x, dy = to.y - from.y
        let len = max(sqrt(dx * dx + dy * dy), 0.001)
        let px = -dy / len * tick, py = dx / len * tick
        for end in [from, to] {
            path.move(to: CGPoint(x: end.x - px, y: end.y - py))
            path.addLine(to: CGPoint(x: end.x + px, y: end.y + py))
        }
        return path
    }
}

/// The highlight rung's spotlight — "look here".
///
/// Vermilion, not heri: this is the app pointing at something, which is the
/// one meaning `Theme.shu` carries. In green it was indistinguishable from a
/// mat's own edge band, which made the spotlight invisible on a laid board.
private struct FocusMarks: View {
    let cells: [Cell]
    let geo: BoardGeometry

    var body: some View {
        ForEach(cells, id: \.self) { cell in
            let f: CGRect = geo.rect(for: cell)
            Rectangle()
                .strokeBorder(Theme.shu, lineWidth: 2)
                .frame(width: f.width, height: f.height)
                .position(x: f.midX, y: f.midY)
        }
    }
}

/// Wrong mats hatched over at the error ladder's highlight rung — crossed
/// out by hand, not lit up in red. See `Theme.hatch`.
private struct ErrorMarks: View {
    let hint: Hint
    let geo: BoardGeometry

    var body: some View {
        ForEach(hint.errorRects, id: \.self) { rect in
            let f: CGRect = geo.rect(for: rect)
            // Error marks always land on a laid mat, so the hatch is dark:
            // see the note in BoardView's mat conflict overlay.
            Hatching(pitch: 6, lineWidth: 1.5, color: .black.opacity(0.55), crossed: true)
                .overlay(Rectangle().strokeBorder(.black.opacity(0.55), lineWidth: 2))
                .frame(width: f.width, height: f.height)
                .position(x: f.midX, y: f.midY)
        }
    }
}

/// The teaching argument, staged by Motion.argumentStagger: candidates ghost
/// in, eliminations strike through, claims burn in.
private struct ArgumentBody: View {
    let step: SolverStep
    let geo: BoardGeometry
    var puzzle: Puzzle? = nil

    @State private var stage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            candidateGhosts
            if stage >= 1 { eliminationStrikes }
            if stage >= 2 { claimBurnIn }
            if stage >= 2 { DimensionArrows(step: step, geo: geo, puzzle: puzzle) }
            if step.technique == .corridorCount, let region = step.explanation.region {
                RegionWash(region: region, geo: geo)
            }
        }
        .onAppear {
            guard !reduceMotion else { stage = 2; return }
            withAnimation(Motion.argumentBeat.delay(Motion.argumentStagger)) { stage = 1 }
            withAnimation(Motion.argumentBeat.delay(Motion.argumentStagger * 3)) { stage = 2 }
        }
    }

    private var candidateGhosts: some View {
        ForEach(step.explanation.candidateRects, id: \.self) { rect in
            let f: CGRect = geo.rect(for: rect)
            Rectangle()
                .strokeBorder(Theme.inkLine.opacity(0.55),
                              style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .frame(width: f.width, height: f.height)
                .position(x: f.midX, y: f.midY)
        }
    }

    private var eliminationStrikes: some View {
        ForEach(step.explanation.eliminatedRects, id: \.self) { rect in
            StruckGhost(rect: rect, geo: geo)
        }
    }

    private var claimBurnIn: some View {
        ForEach(step.explanation.claimedCells, id: \.self) { cell in
            let f: CGRect = geo.rect(for: cell)
            Rectangle()
                .fill(Theme.mat)
                .overlay(Rectangle().strokeBorder(Theme.heri, lineWidth: 1.5))
                .frame(width: f.width, height: f.height)
                .position(x: f.midX, y: f.midY)
                .transition(.opacity)
        }
    }
}

/// A dead placement: the candidate's dashed outline, hatched through.
///
/// This used to be a red dashed border plus a single corner-to-corner slash.
/// Hatching says the same thing in the drawing's own vocabulary and leaves
/// vermilion free to mean "look here" — which is the point the whole overlay
/// is making.
private struct StruckGhost: View {
    let rect: GridRect
    let geo: BoardGeometry

    var body: some View {
        let f: CGRect = geo.rect(for: rect)
        ZStack {
            Hatching(pitch: 6, lineWidth: 1.25)
            Rectangle()
                .strokeBorder(Theme.hatch,
                              style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        }
        .frame(width: f.width, height: f.height)
        .position(x: f.midX, y: f.midY)
        .transition(.opacity)
    }
}

/// The corridor under discussion, washed and edged cell-by-cell. Only the
/// region's outer boundary is stroked — inner cell borders stay clean.
private struct RegionWash: View {
    let region: [Cell]
    let geo: BoardGeometry

    var body: some View {
        let cells = Set(region)
        ForEach(region, id: \.self) { cell in
            let f: CGRect = geo.rect(for: cell)
            Rectangle()
                .fill(Theme.shuWash)
                .overlay(RegionEdge(cell: cell, others: cells).stroke(Theme.shu, lineWidth: 2))
                .frame(width: f.width, height: f.height)
                .position(x: f.midX, y: f.midY)
        }
    }
}

/// Strokes only the sides of a cell that face out of the region.
private struct RegionEdge: Shape {
    let cell: Cell
    let others: Set<Cell>

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if !others.contains(Cell(row: cell.row - 1, col: cell.col)) {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        if !others.contains(Cell(row: cell.row + 1, col: cell.col)) {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        if !others.contains(Cell(row: cell.row, col: cell.col - 1)) {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        if !others.contains(Cell(row: cell.row, col: cell.col + 1)) {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        return path
    }
}

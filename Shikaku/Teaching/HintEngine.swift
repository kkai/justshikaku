//
//  HintEngine.swift
//  Shikaku
//
//  The four-level ladder, ported from the family. Level 3 (highlight) is the
//  destination — the player sees the whole argument drawn and still lays the
//  mat themselves. Level 4 exists without shame but should feel like a small
//  surrender.
//
//  Errors beat teaching at every level: building on a wrong mat wastes
//  everything that follows, and — soundness, not just kindness — the solver
//  state is only trustworthy when every committed mat matches the solution,
//  which is exactly the no-errors condition.
//

import Foundation

nonisolated enum HintLevel: Int, Comparable, Sendable, Codable {
    case nudge, technique, highlight, resolution

    static func < (lhs: HintLevel, rhs: HintLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var next: HintLevel { HintLevel(rawValue: rawValue + 1) ?? .resolution }
}

nonisolated struct Hint: Sendable, Equatable {
    let level: HintLevel
    let step: SolverStep?
    let text: String
    /// Cells to spotlight. Empty below `.highlight` — naming the move is the
    /// whole point of the early rungs, and marking cells gives it away.
    let focusCells: [Cell]
    /// Pointing at a mistake rather than teaching. Errors take priority.
    var isError = false
    /// Withheld behind the unlock.
    var isLocked = false
    /// The wrong mats, for error highlights.
    var errorRects: [GridRect] = []

    /// Whether the drawn argument should run. Gated so early rungs stay talk.
    var showsArgument: Bool { level >= .highlight && !isError && !isLocked }
}

@MainActor
struct HintEngine {

    /// The first rung.
    func hint(
        for game: ShikakuGame,
        mastery: MasteryTracker? = nil,
        showErrors: Bool = true,
        policy: HintPolicy = .full
    ) -> Hint {
        if showErrors, let error = errorHint(for: game, level: .nudge) { return error }

        guard let step = nextStep(for: game) else {
            return Hint(level: .nudge, step: nil,
                        text: TechniqueContent.noErrorAllClear, focusCells: [])
        }

        guard policy == .full else {
            // Deliberately without recordHint: penalising mastery for a hint
            // the player never saw would silently damage their progress path
            // the moment they later pay.
            return Hint(level: .nudge, step: step,
                        text: TechniqueContent.withheld, focusCells: [], isLocked: true)
        }

        mastery?.recordHint(technique: step.technique, level: .nudge)
        return Hint(level: .nudge, step: step,
                    text: TechniqueContent.nudge(for: step.technique),
                    focusCells: [])
    }

    /// The next rung. Stateless recomputation from the stored step rather
    /// than a cursor, so a hint re-renders at any level without re-running
    /// the solver.
    func escalate(
        _ hint: Hint,
        for game: ShikakuGame,
        mastery: MasteryTracker? = nil,
        policy: HintPolicy = .full
    ) -> Hint {
        guard !hint.isLocked else { return hint }
        guard hint.level < .resolution else { return hint }

        let level = hint.level.next

        if hint.isError { return errorHint(for: game, level: level) ?? hint }
        guard policy == .full, let step = hint.step else { return hint }

        mastery?.recordHint(technique: step.technique, level: level)

        let text: String
        switch level {
        case .nudge: text = hint.text
        case .technique: text = TechniqueContent.rule(for: step.technique)
        case .highlight: text = TechniqueContent.detail(for: step, puzzle: game.puzzle)
        case .resolution: text = TechniqueContent.resolution(
            for: step.technique,
            clueValue: step.explanation.clueIndices.first.map { game.puzzle.clues[$0].value } ?? 0)
        }

        return Hint(level: level, step: step, text: text,
                    focusCells: level >= .highlight ? step.focusCells(in: game.puzzle) : [])
    }

    /// Apply a resolution through the game so eliminations materialise as
    /// visible claim marks — Apply must never look like it did nothing.
    func apply(_ hint: Hint, to game: ShikakuGame) {
        guard hint.level == .resolution else { return }
        if hint.isError {
            if let wrong = game.wrongPlacements.min(by: { $0.rect.cells[0] < $1.rect.cells[0] }) {
                game.undoableRemove(wrong)
            }
            return
        }
        guard let step = hint.step else { return }
        if let placement = step.placement {
            game.applyHintPlacement(placement)
        } else if let protagonist = step.explanation.clueIndices.first {
            for cell in step.explanation.claimedCells where game.puzzle.clueIndex(at: cell) == nil {
                game.applyHintClaim(cell: cell, clueIndex: protagonist)
            }
        }
        game.recordHintUsed()
    }

    // MARK: - Solver bridge

    private func nextStep(for game: ShikakuGame) -> SolverStep? {
        let state = SolverState(puzzle: game.puzzle, board: game.board)
        return LogicalSolver.nextStep(puzzle: game.puzzle, state: state)
    }

    // MARK: - Errors

    /// Narrows from "one of your mats isn't right" to the exact mat.
    private func errorHint(for game: ShikakuGame, level: HintLevel) -> Hint? {
        let wrong = game.wrongPlacements
        guard !wrong.isEmpty else { return nil }
        let shown = level >= .resolution ? Array(wrong.prefix(1)) : wrong
        return Hint(
            level: level,
            step: nil,
            text: level >= .resolution ? TechniqueContent.errorResolution
                                       : TechniqueContent.errorNudge,
            focusCells: level >= .highlight ? shown.flatMap { $0.rect.cells } : [],
            isError: true,
            errorRects: level >= .highlight ? shown.map(\.rect) : [])
    }
}

extension SolverStep {
    /// What the highlight rung spotlights: the protagonist clue, any claimed
    /// cells, and the focus cell of the argument.
    nonisolated func focusCells(in puzzle: Puzzle) -> [Cell] {
        var cells: [Cell] = []
        if let protagonist = explanation.clueIndices.first {
            cells.append(puzzle.clues[protagonist].cell)
        }
        cells.append(contentsOf: explanation.claimedCells)
        if let focus = explanation.focusCell {
            cells.append(focus)
        }
        var seen = Set<Cell>()
        return cells.filter { seen.insert($0).inserted }
    }
}

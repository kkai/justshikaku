//
//  LogicalSolver.swift
//  Shikaku
//
//  The human-technique solver. `nextStep` powers hints; `solve` powers the
//  generation gate. Applies the LOWEST-TIER applicable technique, never the
//  first found — otherwise difficulty ratings inflate and hints skip the
//  argument the player could actually make.
//
//  Never a uniqueness proof; that is BacktrackingSolver's only job.
//

import Foundation

/// Live solving state: candidate lists only ever shrink; placements only grow.
nonisolated struct SolverState: Sendable {
    var candidates: [[GridRect]]
    /// placed[i] is clue i's committed rectangle, once known.
    var placed: [GridRect?]

    init(puzzle: Puzzle) {
        candidates = Candidates.enumerate(for: puzzle)
        placed = Array(repeating: nil, count: puzzle.clues.count)
    }

    /// Build state from a player's board: commitments prune exactly as
    /// solver placements do, which is what lets hints meet the player where
    /// they are. Wrong (conflicting) rects are the hint engine's problem —
    /// callers check for errors before asking for a teaching step.
    init(puzzle: Puzzle, board: BoardState) {
        self.init(puzzle: puzzle)
        for p in board.placed where p.rect.area == puzzle.clues[p.clueIndex].value {
            apply(placement: Placement(clueIndex: p.clueIndex, rect: p.rect))
        }
    }

    var allPlaced: Bool { !placed.contains(nil) }

    /// Is the cell inside any committed rectangle?
    func isCovered(_ cell: Cell) -> Bool {
        placed.contains { $0?.contains(cell) ?? false }
    }

    /// Which unplaced clues could still cover each cell — includes the placed
    /// rect's own cells as "reached by owner" so callers need no special case.
    func reachMask(size: Int) -> [ClueMask] {
        var masks = [ClueMask](repeating: ClueMask(), count: size * size)
        for (i, rect) in placed.enumerated() {
            guard let rect else { continue }
            for cell in rect.cells { masks[cell.row * size + cell.col].insert(i) }
        }
        for (i, list) in candidates.enumerated() where placed[i] == nil {
            for rect in list {
                for cell in rect.cells { masks[cell.row * size + cell.col].insert(i) }
            }
        }
        return masks
    }

    /// Commit a rectangle: the clue collapses to it, and every other clue's
    /// overlapping candidates die. This pruning is bookkeeping, not a
    /// technique — a placed mat visibly occupies its space.
    mutating func apply(placement: Placement) {
        placed[placement.clueIndex] = placement.rect
        candidates[placement.clueIndex] = [placement.rect]
        for i in candidates.indices where i != placement.clueIndex && placed[i] == nil {
            candidates[i].removeAll { $0.overlaps(placement.rect) }
        }
    }

    mutating func apply(eliminations: [Elimination]) {
        for e in eliminations {
            candidates[e.clueIndex].removeAll { $0 == e.rect }
        }
    }

    mutating func apply(step: SolverStep) {
        apply(eliminations: step.eliminations)
        if let placement = step.placement { apply(placement: placement) }
    }
}

nonisolated enum LogicalSolver {

    /// The lowest-tier applicable step, or nil when solved or stuck.
    static func nextStep(puzzle: Puzzle, state: SolverState,
                         maxTechnique: Technique = .corridorCount) -> SolverStep? {
        for technique in Technique.allCases where technique <= maxTechnique {
            if let step = detect(technique, puzzle: puzzle, state: state) {
                return step
            }
        }
        return nil
    }

    nonisolated struct SolveResult: Sendable {
        let solved: Bool
        let trace: [SolverStep]
        /// Steps consumed, for the generator's deterministic budget.
        let steps: Int
    }

    /// Run to completion (or stuck) under a technique ceiling.
    static func solve(puzzle: Puzzle, maxTechnique: Technique = .corridorCount,
                      budget: inout Int) -> SolveResult {
        var state = SolverState(puzzle: puzzle)
        var trace: [SolverStep] = []
        while !state.allPlaced {
            guard budget > 0,
                  let step = nextStep(puzzle: puzzle, state: state, maxTechnique: maxTechnique)
            else {
                return SolveResult(solved: false, trace: trace, steps: trace.count)
            }
            budget -= 1
            state.apply(step: step)
            trace.append(step)
        }
        return SolveResult(solved: true, trace: trace, steps: trace.count)
    }

    /// The techniques in the deduction that reaches a placement for
    /// `clueIndex` from `state` — the mastery tracker's evidence that an
    /// unaided placement was actually derivable, and by what.
    ///
    /// Runs the normal lowest-technique-first loop, collecting only the steps
    /// that bear on the target (eliminations of the target's candidates, and
    /// the placement itself); steps that merely place *other* clues on the
    /// way are bookkeeping for the state, not part of this argument, and
    /// crediting them would inflate mastery. Returns nil when the solver
    /// cannot reach the placement — the player out-reasoned the curriculum
    /// (or guessed), and neither earns a seal.
    static func chain(toPlace clueIndex: Int, puzzle: Puzzle,
                      state initial: SolverState, maxSteps: Int = 96) -> [Technique]? {
        var state = initial
        guard state.placed[clueIndex] == nil else { return nil }
        var techniques: [Technique] = []
        for _ in 0..<maxSteps {
            guard let step = nextStep(puzzle: puzzle, state: state) else { return nil }
            let bearsOnTarget = step.placement?.clueIndex == clueIndex
                || step.eliminations.contains { $0.clueIndex == clueIndex }
            if bearsOnTarget { techniques.append(step.technique) }
            state.apply(step: step)
            if state.placed[clueIndex] != nil {
                return techniques.isEmpty ? nil : techniques
            }
        }
        return nil
    }

    // MARK: - Detectors

    private static func detect(_ technique: Technique, puzzle: Puzzle,
                               state: SolverState) -> SolverStep? {
        switch technique {
        case .oneCell: detectOneCell(puzzle: puzzle, state: state)
        case .primeStrip: detectSingleCandidate(puzzle: puzzle, state: state, primeOnly: true)
        case .onlyFit: detectSingleCandidate(puzzle: puzzle, state: state, primeOnly: false)
        case .mustCover: detectMustCover(puzzle: puzzle, state: state)
        case .soleOwner: detectSoleOwner(puzzle: puzzle, state: state)
        case .strandedCell: detectStranded(puzzle: puzzle, state: state)
        case .corridorCount: detectCorridorCount(puzzle: puzzle, state: state)
        }
    }

    private static func detectOneCell(puzzle: Puzzle, state: SolverState) -> SolverStep? {
        for (i, clue) in puzzle.clues.enumerated()
        where clue.value == 1 && state.placed[i] == nil {
            let rect = GridRect(origin: clue.cell, width: 1, height: 1)
            return SolverStep(
                technique: .oneCell,
                placement: Placement(clueIndex: i, rect: rect),
                eliminations: [],
                explanation: ExplanationData(clueIndices: [i], candidateRects: [rect]))
        }
        return nil
    }

    /// primeStrip and onlyFit share a detector; primeStrip narrows it to
    /// prime values (> 1) so the simpler argument fires first.
    private static func detectSingleCandidate(puzzle: Puzzle, state: SolverState,
                                              primeOnly: Bool) -> SolverStep? {
        for (i, clue) in puzzle.clues.enumerated() where state.placed[i] == nil {
            if primeOnly && !isPrime(clue.value) { continue }
            guard state.candidates[i].count == 1, let rect = state.candidates[i].first else { continue }
            // oneCell owns value 1; don't relabel it.
            guard clue.value > 1 else { continue }
            let all = Candidates.rects(forClue: i, in: puzzle)
            let eliminated = all.filter { $0 != rect }
            return SolverStep(
                technique: primeOnly ? .primeStrip : .onlyFit,
                placement: Placement(clueIndex: i, rect: rect),
                eliminations: [],
                explanation: ExplanationData(
                    clueIndices: [i],
                    candidateRects: [rect],
                    eliminatedRects: eliminated))
        }
        return nil
    }

    private static func detectMustCover(puzzle: Puzzle, state: SolverState) -> SolverStep? {
        for (i, _) in puzzle.clues.enumerated()
        where state.placed[i] == nil && state.candidates[i].count >= 2 {
            // Intersect all candidates: interval min/max, O(candidates).
            var minR = Int.min, minC = Int.min, maxR = Int.max, maxC = Int.max
            for rect in state.candidates[i] {
                minR = max(minR, rect.minRow); minC = max(minC, rect.minCol)
                maxR = min(maxR, rect.maxRow); maxC = min(maxC, rect.maxCol)
            }
            guard minR <= maxR && minC <= maxC else { continue }
            let core = GridRect(minRow: minR, minCol: minC, maxRow: maxR, maxCol: maxC)
            // Fires only when the claim kills at least one foreign candidate —
            // a claim that changes nothing is not a step.
            var eliminations: [Elimination] = []
            for (j, list) in state.candidates.enumerated()
            where j != i && state.placed[j] == nil {
                for rect in list where rect.overlaps(core) {
                    eliminations.append(Elimination(clueIndex: j, rect: rect))
                }
            }
            guard !eliminations.isEmpty else { continue }
            return SolverStep(
                technique: .mustCover,
                placement: nil,
                eliminations: eliminations,
                explanation: ExplanationData(
                    clueIndices: [i] + orderedClueIndices(of: eliminations),
                    candidateRects: state.candidates[i],
                    eliminatedRects: eliminations.map(\.rect),
                    claimedCells: core.cells))
        }
        return nil
    }

    private static func detectSoleOwner(puzzle: Puzzle, state: SolverState) -> SolverStep? {
        let masks = state.reachMask(size: puzzle.size)
        for row in 0..<puzzle.size {
            for col in 0..<puzzle.size {
                let cell = Cell(row: row, col: col)
                guard !state.isCovered(cell),
                      let owner = masks[row * puzzle.size + col].only,
                      state.placed[owner] == nil
                else { continue }
                let eliminations = state.candidates[owner]
                    .filter { !$0.contains(cell) }
                    .map { Elimination(clueIndex: owner, rect: $0) }
                guard !eliminations.isEmpty else { continue }
                return SolverStep(
                    technique: .soleOwner,
                    placement: nil,
                    eliminations: eliminations,
                    explanation: ExplanationData(
                        clueIndices: [owner],
                        candidateRects: state.candidates[owner].filter { $0.contains(cell) },
                        eliminatedRects: eliminations.map(\.rect),
                        claimedCells: [cell],
                        focusCell: cell))
            }
        }
        return nil
    }

    private static func detectStranded(puzzle: Puzzle, state: SolverState) -> SolverStep? {
        for (i, list) in state.candidates.enumerated() where state.placed[i] == nil {
            guard list.count >= 2 else { continue }
            for rect in list {
                var hypo = state
                hypo.apply(placement: Placement(clueIndex: i, rect: rect))
                if let stranded = firstUnreachableCell(puzzle: puzzle, state: hypo) {
                    return SolverStep(
                        technique: .strandedCell,
                        placement: nil,
                        eliminations: [Elimination(clueIndex: i, rect: rect)],
                        explanation: ExplanationData(
                            clueIndices: [i],
                            candidateRects: [],
                            eliminatedRects: [rect],
                            focusCell: stranded))
                }
            }
        }
        return nil
    }

    private static func detectCorridorCount(puzzle: Puzzle, state: SolverState) -> SolverStep? {
        for (i, list) in state.candidates.enumerated() where state.placed[i] == nil {
            guard list.count >= 2 else { continue }
            for rect in list {
                var hypo = state
                hypo.apply(placement: Placement(clueIndex: i, rect: rect))
                if let (region, best) = firstUndercountedRegion(puzzle: puzzle, state: hypo) {
                    return SolverStep(
                        technique: .corridorCount,
                        placement: nil,
                        eliminations: [Elimination(clueIndex: i, rect: rect)],
                        explanation: ExplanationData(
                            clueIndices: [i],
                            candidateRects: [],
                            eliminatedRects: [rect],
                            region: region,
                            areaNumbers: [region.count, best]))
                }
            }
        }
        return nil
    }

    // MARK: - Shared analysis

    static func firstUnreachableCell(puzzle: Puzzle, state: SolverState) -> Cell? {
        let masks = state.reachMask(size: puzzle.size)
        for row in 0..<puzzle.size {
            for col in 0..<puzzle.size where masks[row * puzzle.size + col].isEmpty {
                return Cell(row: row, col: col)
            }
        }
        return nil
    }

    /// First connected uncovered region whose reaching clues' best fits sum
    /// below its area, with that sum. Regions in reading order — determinism.
    static func firstUndercountedRegion(puzzle: Puzzle, state: SolverState) -> (region: [Cell], best: Int)? {
        let size = puzzle.size
        var visited = [Bool](repeating: false, count: size * size)
        for row in 0..<size {
            for col in 0..<size {
                let start = Cell(row: row, col: col)
                guard !visited[row * size + col], !state.isCovered(start) else { continue }
                // Flood fill.
                var region: [Cell] = []
                var stack = [start]
                visited[row * size + col] = true
                while let cell = stack.popLast() {
                    region.append(cell)
                    for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                        let nr = cell.row + dr, nc = cell.col + dc
                        guard nr >= 0, nr < size, nc >= 0, nc < size,
                              !visited[nr * size + nc],
                              !state.isCovered(Cell(row: nr, col: nc))
                        else { continue }
                        visited[nr * size + nc] = true
                        stack.append(Cell(row: nr, col: nc))
                    }
                }
                // Best-case contribution of each unplaced clue reaching the region.
                let regionSet = Set(region)
                var best = 0
                for (i, list) in state.candidates.enumerated() where state.placed[i] == nil {
                    var clueBest = 0
                    for rect in list {
                        var overlap = 0
                        for cell in rect.cells where regionSet.contains(cell) { overlap += 1 }
                        clueBest = max(clueBest, overlap)
                    }
                    best += clueBest
                }
                if best < region.count {
                    return (region.sorted(), best)
                }
            }
        }
        return nil
    }

    static func isPrime(_ n: Int) -> Bool {
        guard n >= 2 else { return false }
        var d = 2
        while d * d <= n {
            if n % d == 0 { return false }
            d += 1
        }
        return true
    }

    /// Eliminated clues in first-seen order, deduplicated deterministically.
    private static func orderedClueIndices(of eliminations: [Elimination]) -> [Int] {
        var seen = Set<Int>()
        var out: [Int] = []
        for e in eliminations where seen.insert(e.clueIndex).inserted {
            out.append(e.clueIndex)
        }
        return out
    }
}

//
//  ShikakuGenerator.swift
//  Shikaku
//
//  Generation invariant, enforced at this file's single exit: every returned
//  puzzle is provably unique (BacktrackingSolver) AND fully solvable by
//  LogicalSolver under the requested tier's technique ceiling. A board
//  failing either test is never returned — this is what makes the hint
//  guarantee real.
//
//  Bounded by a DETERMINISTIC node budget (never wall-clock, never attempt
//  counts alone) so per-seed determinism holds and generation tests cannot
//  go flaky. Baked fallbacks cover budget exhaustion.
//

import Foundation

nonisolated enum BoardSize: Int, CaseIterable, Codable, Sendable, Identifiable {
    case five = 5, seven = 7, ten = 10, twelve = 12

    var id: Int { rawValue }
}

nonisolated struct GenerationResult: Sendable {
    let puzzle: Puzzle
    let grade: Difficulty
    let trace: [SolverStep]
    /// True when the budget ran out and a baked fallback was returned.
    let isFallback: Bool
}

nonisolated enum ShikakuGenerator {

    /// Total node budget per generate() call, spent across partitioning,
    /// uniqueness proofs, and solver runs. Deterministic by construction.
    static let nodeBudget = 400_000

    /// Requested-tier generation: grades candidates and returns one in the
    /// requested band, falling back to the nearest grade rather than refusing
    /// — and to a baked board when the budget is exhausted. Wire the returned
    /// grade to the UI; never staple the requested label onto the result
    /// (a sibling shipped that bug and its tiers meant nothing).
    static func generate(size: BoardSize, tier: Difficulty, seed: UInt64,
                         isCancelled: () -> Bool = { false }) -> GenerationResult {
        var rng = SeededRandomNumberGenerator(seed: seed)
        var budget = nodeBudget
        var nearest: GenerationResult? = nil

        while budget > 0 && !isCancelled() {
            guard let puzzle = attempt(size: size.rawValue, tier: tier,
                                       rng: &rng, budget: &budget) else { continue }

            // Uniqueness. nil = budget ran out mid-proof: unknown, not unique.
            guard let count = BacktrackingSolver.countSolutions(
                puzzle: puzzle, limit: 2, budget: &budget), count == 1 else { continue }

            // Solvability under the ceiling — the curriculum gate.
            let result = LogicalSolver.solve(
                puzzle: puzzle, maxTechnique: tier.techniqueCeiling, budget: &budget)
            guard result.solved else { continue }

            let grade = DifficultyRater.grade(trace: result.trace, size: size.rawValue)
            let generated = GenerationResult(
                puzzle: puzzle, grade: grade, trace: result.trace, isFallback: false)
            if grade == tier { return generated }
            // Keep the closest off-band board in case the budget runs dry.
            if nearest == nil ||
                abs(grade.rawValue - tier.rawValue) <
                abs(nearest!.grade.rawValue - tier.rawValue) {
                nearest = generated
            }
        }

        if let nearest { return nearest }
        return bakedFallback(size: size, tier: tier)
    }

    // MARK: - One attempt

    private static func attempt(size: Int, tier: Difficulty,
                                rng: inout SeededRandomNumberGenerator,
                                budget: inout Int) -> Puzzle? {
        guard let rects = partition(size: size, tier: tier, rng: &rng, budget: &budget)
        else { return nil }

        // Quality bars, all as a share of CELLS (mixing units with a share of
        // pieces silently rejected everything once, in a sibling).
        let cellCount = size * size
        let freebieCells = rects.filter { $0.area == 1 }.count
        let dominoCells = rects.filter { $0.area == 2 }.count * 2
        let freebieCap: Double = switch tier {
        case .gentle: 0.10
        case .steady: 0.06
        case .sharp: 0.04
        case .deep, .severe: 0.0
        }
        guard Double(freebieCells) / Double(cellCount) <= freebieCap else { return nil }
        guard Double(dominoCells) / Double(cellCount) <= 0.34 else { return nil }

        let clues = rects.map { rect in
            Clue(cell: clueCell(in: rect, size: size, tier: tier, rng: &rng), value: rect.area)
        }
        return Puzzle(size: size, clues: clues, solution: rects)
    }

    /// Scanline packing: repeatedly take the topmost-leftmost uncovered cell
    /// and grow a random fitting rectangle there. Reading-order seeding is
    /// deliberate — random seeding fragments free space and strands unwanted
    /// 1×1s (a sibling measured 21–24% against a requested 6%).
    private static func partition(size: Int, tier: Difficulty,
                                  rng: inout SeededRandomNumberGenerator,
                                  budget: inout Int) -> [GridRect]? {
        var covered = [Bool](repeating: false, count: size * size)
        var rects: [GridRect] = []
        let maxArea = min(targetMaxArea(tier: tier, size: size), size * size)

        var cursor = 0
        while cursor < size * size {
            if covered[cursor] { cursor += 1; continue }
            guard budget > 0 else { return nil }
            budget -= 1

            let row = cursor / size, col = cursor % size

            // All (w,h) whose rect anchored here is fully uncovered.
            var options: [(w: Int, h: Int)] = []
            var maxW = 0
            while col + maxW < size && !covered[row * size + col + maxW] { maxW += 1 }
            for w in 1...maxW {
                var h = 1
                heightLoop: while row + h - 1 < size && w * h <= maxArea {
                    for c in col..<(col + w) where covered[(row + h - 1) * size + c] {
                        break heightLoop
                    }
                    if w * h >= 1 { options.append((w, h)) }
                    h += 1
                }
            }

            // Bias the size distribution upward: large pieces statistically
            // fail to fit, so the empirical result skews smaller anyway.
            let weighted = options.map { (option: $0, weight: $0.w * $0.h * $0.w * $0.h) }
            let total = weighted.reduce(0) { $0 + $1.weight }
            var pick = Int(rng.next() % UInt64(max(total, 1)))
            var chosen = options[0]
            for (option, weight) in weighted {
                if pick < weight { chosen = option; break }
                pick -= weight
            }

            let rect = GridRect(origin: Cell(row: row, col: col),
                                width: chosen.w, height: chosen.h)
            rects.append(rect)
            for cell in rect.cells { covered[cell.row * size + cell.col] = true }
        }
        return rects
    }

    private static func targetMaxArea(tier: Difficulty, size: Int) -> Int {
        // Larger pieces make more placement ambiguity; cap gentle boards low.
        switch tier {
        case .gentle: min(6, size)
        case .steady: 8
        case .sharp: 9
        case .deep: 12
        case .severe: 12
        }
    }

    /// The main difficulty lever. A clue hugging its rectangle's corner (and
    /// the grid's walls) has few geometric fits; a central clue has many.
    private static func clueCell(in rect: GridRect, size: Int, tier: Difficulty,
                                 rng: inout SeededRandomNumberGenerator) -> Cell {
        let cells = rect.cells
        guard cells.count > 1 else { return cells[0] }

        // Pure-geometry candidate count (ignores other clues): exact enough
        // to rank cells, and cheap.
        func geometryFits(_ cell: Cell) -> Int {
            var fits = 0
            var h = 1
            while h <= min(rect.area, size) {
                defer { h += 1 }
                guard rect.area % h == 0 else { continue }
                let w = rect.area / h
                guard w <= size else { continue }
                let rows = min(cell.row, size - h) - max(0, cell.row - h + 1) + 1
                let cols = min(cell.col, size - w) - max(0, cell.col - w + 1) + 1
                if rows > 0 && cols > 0 { fits += rows * cols }
            }
            return fits
        }

        switch tier {
        case .gentle:
            return cells.min { geometryFits($0) < geometryFits($1) }!
        case .steady:
            return cells[Int(rng.next() % UInt64(cells.count))]
        case .sharp:
            // Random among the more ambiguous half.
            let ranked = cells.sorted { geometryFits($0) > geometryFits($1) }
            let half = ranked[0..<max(1, ranked.count / 2)]
            return half[half.startIndex + Int(rng.next() % UInt64(half.count))]
        case .deep, .severe:
            return cells.max { geometryFits($0) < geometryFits($1) }!
        }
    }

    // MARK: - Fallback

    /// Pre-verified baked boards for the budget-exhausted path. Re-proven
    /// unique and solvable by the EngineCheck harness on every run.
    static func bakedFallback(size: BoardSize, tier: Difficulty) -> GenerationResult {
        let puzzle = BakedPuzzles.puzzle(size: size)
        var budget = nodeBudget
        let result = LogicalSolver.solve(puzzle: puzzle, budget: &budget)
        return GenerationResult(
            puzzle: puzzle,
            grade: DifficultyRater.grade(trace: result.trace, size: size.rawValue),
            trace: result.trace,
            isFallback: true)
    }
}

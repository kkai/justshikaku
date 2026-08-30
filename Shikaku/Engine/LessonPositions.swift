import Foundation

/// Mid-solve positions where one named technique is the applicable move —
/// the raw material of Spot It drills, and the same search the lesson-board
/// harness runs (`SHIKAKU_LESSONS=1`), now callable from the app.
///
/// A position is (puzzle, pre-laid placements) such that, rebuilding solver
/// state **from the placements alone** — exactly how the app reconstructs a
/// board — the first applicable technique is the target. The player's task
/// is to lay a mat that the target helps justify.
nonisolated enum LessonPositions {

    struct Position: Sendable, Equatable {
        let puzzle: Puzzle
        let preplaced: [Placement]
        /// The clue whose placement the position is asking for: the first
        /// placement the solver makes from here. Laying its solution rect is
        /// the correct answer.
        let answerClue: Int

        var startingBoard: BoardState {
            BoardState(placed: preplaced.map {
                PlacedRect(rect: $0.rect, clueIndex: $0.clueIndex)
            }, claims: [:])
        }
    }

    /// Walks generated boards (seeded, deterministic) and harvests up to
    /// `count` positions for `technique`. One board can yield several. May
    /// return fewer when the budget runs out — callers cycle what they get.
    static func mine(technique: Technique, count: Int, seed: UInt64,
                     isCancelled: () -> Bool = { false }) -> [Position] {
        var positions: [Position] = []
        var boardSeed = seed
        var boardsTried = 0
        // The tail techniques live in small sharp/deep boards; the early
        // ones are everywhere. Same ladder the harness uses.
        let sources: [(BoardSize, Difficulty)] = technique <= .onlyFit
            ? [(.five, .gentle), (.five, .steady)]
            : [(.five, .sharp), (.five, .deep), (.seven, .deep), (.seven, .severe)]

        while positions.count < count, boardsTried < 24, !isCancelled() {
            for (size, tier) in sources where positions.count < count {
                if isCancelled() { break }
                let result = ShikakuGenerator.generate(
                    size: size, tier: tier, seed: boardSeed,
                    isCancelled: isCancelled)
                boardsTried += 1
                guard !result.isFallback else { continue }
                harvest(from: result.puzzle, technique: technique,
                        into: &positions, limit: count)
            }
            boardSeed &+= 0x9E37_79B9_7F4A_7C15
        }
        return positions
    }

    /// One walk down a board's solve, collecting each mid-state where the
    /// target is first-applicable from the placements alone.
    private static func harvest(from puzzle: Puzzle, technique: Technique,
                                into positions: inout [Position], limit: Int) {
        var state = SolverState(puzzle: puzzle)
        var placements: [Placement] = []
        var steps = 0
        while !state.allPlaced, steps < 500, positions.count < limit,
              let step = LogicalSolver.nextStep(puzzle: puzzle, state: state) {
            steps += 1
            var fresh = SolverState(puzzle: puzzle)
            for p in placements { fresh.apply(placement: p) }
            if let first = LogicalSolver.nextStep(puzzle: puzzle, state: fresh),
               first.technique == technique,
               let answer = nextPlacementClue(puzzle: puzzle, from: fresh) {
                // Skip trivially-early positions (an empty board asks
                // nothing) and duplicates of ones already collected.
                if !placements.isEmpty {
                    let position = Position(puzzle: puzzle,
                                            preplaced: placements,
                                            answerClue: answer)
                    if !positions.contains(position) {
                        positions.append(position)
                    }
                }
            }
            state.apply(step: step)
            if let p = step.placement { placements.append(p) }
        }
    }

    /// The clue the solver would place next from this state, running
    /// through any elimination-only steps to reach it.
    private static func nextPlacementClue(puzzle: Puzzle,
                                          from initial: SolverState) -> Int? {
        var state = initial
        for _ in 0..<64 {
            guard let step = LogicalSolver.nextStep(puzzle: puzzle, state: state)
            else { return nil }
            if let placement = step.placement { return placement.clueIndex }
            state.apply(step: step)
        }
        return nil
    }
}

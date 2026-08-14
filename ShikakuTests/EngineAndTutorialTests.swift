//
//  EngineAndTutorialTests.swift
//  ShikakuTests
//
//  The app-target slice of engine verification. The EngineCheck harness
//  carries the heavy differential suites (it compiles in seconds, without a
//  simulator); these tests pin what the APP depends on: lesson boards
//  exercising their techniques, baked fallbacks staying provable, and the
//  solver bridge the hint engine uses.
//

import Testing
@testable import Shikaku

@Suite struct TutorialFixtureTests {

    /// Every lesson board must be a valid, unique partition whose FIRST
    /// applicable technique — reconstructed from placements alone, exactly
    /// as LessonView does — is the technique it claims to teach. If
    /// detector precedence changes, this fails instead of a player noticing.
    @Test(arguments: Technique.allCases)
    func lessonBoardExercisesItsTechnique(technique: Technique) {
        let lesson = TutorialPuzzles.lesson(for: technique)
        #expect(isValidPartition(lesson.puzzle))

        var budget = 100_000
        let solutions = BacktrackingSolver.countSolutions(
            puzzle: lesson.puzzle, limit: 2, budget: &budget)
        #expect(solutions == 1)

        var state = SolverState(puzzle: lesson.puzzle)
        for placed in lesson.preplaced {
            state.apply(placement: Placement(clueIndex: placed.clueIndex, rect: placed.rect))
        }
        let first = LogicalSolver.nextStep(puzzle: lesson.puzzle, state: state)
        #expect(first?.technique == technique)
    }

    /// The lesson flow needs a placement to ask for after the argument.
    @Test(arguments: Technique.allCases)
    func lessonBoardYieldsAPlacementAfterTheArgument(technique: Technique) {
        let lesson = TutorialPuzzles.lesson(for: technique)
        var state = SolverState(puzzle: lesson.puzzle)
        for placed in lesson.preplaced {
            state.apply(placement: Placement(clueIndex: placed.clueIndex, rect: placed.rect))
        }
        var sawTechnique = false
        var foundPlacement = false
        var guardCount = 0
        while guardCount < 100,
              let step = LogicalSolver.nextStep(puzzle: lesson.puzzle, state: state) {
            guardCount += 1
            if step.technique == technique { sawTechnique = true }
            if step.placement != nil && sawTechnique { foundPlacement = true; break }
            state.apply(step: step)
        }
        #expect(sawTechnique && foundPlacement)
    }

    @Test func rulesBoardIsATinyCompleteGame() {
        let rules = TutorialPuzzles.rules
        #expect(rules.puzzle.size == 3)
        #expect(isValidPartition(rules.puzzle))
        #expect(rules.preplacedClues.isEmpty)
    }

    private func isValidPartition(_ puzzle: Puzzle) -> Bool {
        var covered = [Bool](repeating: false, count: puzzle.size * puzzle.size)
        for (i, rect) in puzzle.solution.enumerated() {
            guard puzzle.inBounds(rect), rect.area == puzzle.clues[i].value,
                  rect.contains(puzzle.clues[i].cell) else { return false }
            for cell in rect.cells {
                if covered[cell.row * puzzle.size + cell.col] { return false }
                covered[cell.row * puzzle.size + cell.col] = true
            }
        }
        return !covered.contains(false)
    }
}

@Suite struct HintEngineTests {

    @MainActor
    private func makeGame() -> ShikakuGame {
        let lesson = TutorialPuzzles.lesson(for: .onlyFit)
        return ShikakuGame(puzzle: lesson.puzzle, size: .five, difficulty: .gentle)
    }

    @MainActor @Test func ladderEscalatesOneRungAtATime() {
        let game = makeGame()
        let engine = HintEngine()
        var hint = engine.hint(for: game)
        #expect(hint.level == .nudge)
        #expect(hint.focusCells.isEmpty)

        hint = engine.escalate(hint, for: game)
        #expect(hint.level == .technique)
        #expect(hint.focusCells.isEmpty)

        hint = engine.escalate(hint, for: game)
        #expect(hint.level == .highlight)
        #expect(!hint.focusCells.isEmpty)
        #expect(hint.showsArgument)

        hint = engine.escalate(hint, for: game)
        #expect(hint.level == .resolution)
        #expect(hint.step?.placement != nil)

        // The top rung holds.
        let again = engine.escalate(hint, for: game)
        #expect(again.level == .resolution)
    }

    @MainActor @Test func errorsBeatTeaching() {
        let game = makeGame()
        // A wrong-area mat commits by design (the error tier needs a
        // subject); it is also solution-wrong, so the hint must point at it
        // rather than teach.
        let wrong = GridRect(minRow: 0, minCol: 0, maxRow: 0, maxCol: 1)
        game.dragChanged(anchor: Cell(row: 0, col: 0), current: Cell(row: 0, col: 1))
        game.dragEnded()
        #expect(game.board.placed.contains { $0.rect == wrong })

        let hint = HintEngine().hint(for: game)
        #expect(hint.isError)

        // Climbing the error ladder ends in lifting the wrong mat.
        var top = hint
        for _ in 0..<3 { top = HintEngine().escalate(top, for: game) }
        #expect(top.level == .resolution && top.isError)
        HintEngine().apply(top, to: game)
        #expect(game.board.placed.isEmpty)
    }

    @MainActor @Test func lockedPolicyWithholdsWithoutRecordingMastery() {
        let game = makeGame()
        let hint = HintEngine().hint(for: game, policy: .errorsOnly)
        #expect(hint.isLocked)
        // Escalation is inert while locked.
        let escalated = HintEngine().escalate(hint, for: game, policy: .errorsOnly)
        #expect(escalated == hint)
    }
}

@Suite struct BakedFallbackTests {

    /// Baked boards are the budget-exhaustion safety net; they must stay
    /// unique and curriculum-solvable through any engine change.
    @Test(arguments: BoardSize.allCases)
    func bakedBoardStaysProvable(size: BoardSize) {
        let puzzle = BakedPuzzles.puzzle(size: size)
        var budget = ShikakuGenerator.nodeBudget
        #expect(BacktrackingSolver.countSolutions(puzzle: puzzle, limit: 2, budget: &budget) == 1)
        var solveBudget = ShikakuGenerator.nodeBudget
        #expect(LogicalSolver.solve(puzzle: puzzle, budget: &solveBudget).solved)
    }
}

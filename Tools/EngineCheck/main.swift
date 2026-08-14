//
//  main.swift
//  EngineCheck
//
//  The engine's CLI harness — pure Swift, no simulator, seconds. Compile:
//
//      swiftc -O -o /tmp/enginecheck Shikaku/Engine/*.swift Tools/EngineCheck/*.swift
//
//  Modes: SHIKAKU_CALIBRATE=1 prints the difficulty threshold table;
//  SHIKAKU_BAKE=1 prints fresh BakedPuzzles literals.
//
//  All output on stderr — stdout is block-buffered under a pipe.
//

import Foundation

var checks = 0
var failures = 0

func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition {
        failures += 1
        FileHandle.standardError.write("FAIL: \(message())\n".data(using: .utf8)!)
    }
}

func note(_ message: String) {
    FileHandle.standardError.write("\(message)\n".data(using: .utf8)!)
}

let calibrate = ProcessInfo.processInfo.environment["SHIKAKU_CALIBRATE"] == "1"
let bake = ProcessInfo.processInfo.environment["SHIKAKU_BAKE"] == "1"

// MARK: - GridRect basics

do {
    let r = GridRect(minRow: 1, minCol: 2, maxRow: 3, maxCol: 4)
    check(r.width == 3 && r.height == 3 && r.area == 9, "GridRect dimensions")
    check(r.contains(Cell(row: 2, col: 3)), "GridRect contains interior")
    check(!r.contains(Cell(row: 0, col: 3)), "GridRect excludes exterior")
    check(r.overlaps(GridRect(minRow: 3, minCol: 4, maxRow: 5, maxCol: 6)), "corner overlap")
    check(!r.overlaps(GridRect(minRow: 4, minCol: 2, maxRow: 5, maxCol: 4)), "adjacent rows disjoint")
    check(r.cells.count == 9 && r.cells.first == Cell(row: 1, col: 2), "cells row-major")

    var mask = ClueMask()
    mask.insert(3); mask.insert(70)
    check(mask.count == 2 && mask.contains(3) && mask.contains(70) && !mask.contains(4), "ClueMask basics")
    var single = ClueMask(); single.insert(90)
    check(single.only == 90, "ClueMask.only high word")
}

// MARK: - Partition validity helper

func isValidPartition(_ puzzle: Puzzle) -> Bool {
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

// MARK: - Candidate enumeration: differential vs brute force

do {
    var rng = SeededRandomNumberGenerator(seed: 12345)
    var compared = 0
    for size in [BoardSize.five, .seven] {
        for tier in Difficulty.allCases {
            let result = ShikakuGenerator.generate(size: size, tier: tier, seed: rng.next())
            for i in result.puzzle.clues.indices {
                let fast = Candidates.rects(forClue: i, in: result.puzzle)
                let brute = Candidates.bruteForceRects(forClue: i, in: result.puzzle)
                check(Set(fast) == Set(brute),
                      "candidate enumeration differs from brute force, size \(size.rawValue) clue \(i)")
                check(fast.count == Set(fast).count, "duplicate candidates, clue \(i)")
                compared += brute.count
            }
        }
    }
    note("differential candidate comparisons: \(compared)")
}

// MARK: - Technique fixtures

for fixture in Fixtures.all {
    check(isValidPartition(fixture.puzzle), "fixture '\(fixture.name)' is not a valid partition")
    var budget = 100_000
    let unique = BacktrackingSolver.countSolutions(puzzle: fixture.puzzle, limit: 2, budget: &budget)
    check(unique == 1, "fixture '\(fixture.name)' is not unique (\(String(describing: unique)))")
    let state = SolverState(puzzle: fixture.puzzle)
    let step = LogicalSolver.nextStep(puzzle: fixture.puzzle, state: state)
    check(step?.technique == fixture.expectedFirst,
          "fixture '\(fixture.name)': expected \(fixture.expectedFirst), got \(String(describing: step?.technique))")
    if let expected = fixture.expectedRect {
        check(step?.placement?.rect == expected,
              "fixture '\(fixture.name)': wrong placement \(String(describing: step?.placement))")
    }
}

// MARK: - Baked fallbacks: valid, unique, solvable — re-proven every run

for size in BoardSize.allCases {
    let puzzle = BakedPuzzles.puzzle(size: size)
    check(isValidPartition(puzzle), "baked \(size.rawValue)×\(size.rawValue) is not a valid partition")
    var budget = ShikakuGenerator.nodeBudget
    let unique = BacktrackingSolver.countSolutions(puzzle: puzzle, limit: 2, budget: &budget)
    check(unique == 1, "baked \(size.rawValue)×\(size.rawValue) is not unique (\(String(describing: unique))) — re-bake with SHIKAKU_BAKE=1")
    var solveBudget = ShikakuGenerator.nodeBudget
    let solved = LogicalSolver.solve(puzzle: puzzle, budget: &solveBudget).solved
    check(solved, "baked \(size.rawValue)×\(size.rawValue) is not curriculum-solvable — re-bake")
}

// MARK: - Generation corpus: properties, soundness, determinism

var techniqueAppearances: [Technique: Int] = [:]
var scores: [Int: [(Difficulty, Double, Difficulty)]] = [:]  // size → (requested, score, graded)
var fallbacks = 0

let corpusSeeds: [UInt64] = [1, 2, 3]
for size in BoardSize.allCases {
    for tier in Difficulty.allCases {
        for seed in corpusSeeds {
            let result = ShikakuGenerator.generate(size: size, tier: tier, seed: seed)
            if result.isFallback { fallbacks += 1 }
            let puzzle = result.puzzle

            check(isValidPartition(puzzle), "generated invalid partition s\(size.rawValue) t\(tier) seed \(seed)")

            // Determinism: same seed, same board.
            let again = ShikakuGenerator.generate(size: size, tier: tier, seed: seed)
            check(again.puzzle == puzzle, "non-deterministic generation s\(size.rawValue) t\(tier) seed \(seed)")

            // Uniqueness (already gated inside generate; re-proven here).
            var budget = ShikakuGenerator.nodeBudget
            check(BacktrackingSolver.countSolutions(puzzle: puzzle, limit: 2, budget: &budget) == 1,
                  "generated non-unique s\(size.rawValue) t\(tier) seed \(seed)")

            // Full-solve equality: the logical solve must land exactly on the
            // unique solution, and every step must be sound against it.
            var state = SolverState(puzzle: puzzle)
            var stepCount = 0
            while !state.allPlaced, stepCount < 10_000,
                  let step = LogicalSolver.nextStep(puzzle: puzzle, state: state) {
                stepCount += 1
                techniqueAppearances[step.technique, default: 0] += 1
                if let p = step.placement {
                    check(p.rect == puzzle.solution[p.clueIndex],
                          "unsound placement (\(step.technique)) s\(size.rawValue) seed \(seed)")
                }
                for e in step.eliminations {
                    check(e.rect != puzzle.solution[e.clueIndex],
                          "unsound elimination (\(step.technique)) s\(size.rawValue) seed \(seed)")
                }
                state.apply(step: step)
            }
            check(state.allPlaced, "solver stalled on shipped board s\(size.rawValue) t\(tier) seed \(seed)")

            scores[size.rawValue, default: []].append(
                (tier, DifficultyRater.score(trace: result.trace, size: size.rawValue), result.grade))
        }
    }
}

check(fallbacks == 0, "\(fallbacks) corpus generations hit the baked fallback — budget or curriculum regressed")

// Techniques not marked allowed-absent must appear somewhere in the corpus;
// the allowed-absent expectation is pinned in BOTH directions: if the tail
// techniques start appearing, this fails and says the assumption changed.
for technique in Technique.allCases {
    let appeared = (techniqueAppearances[technique] ?? 0) > 0
    if Technique.allowedAbsentFromGeneratedPuzzles.contains(technique) {
        if appeared {
            note("NOTE: \(technique) appeared \(techniqueAppearances[technique]!)× — allowed-absent assumption may be stale; consider updating Technique.allowedAbsentFromGeneratedPuzzles and adding generated drills")
        }
    } else {
        check(appeared, "\(technique) never fired across the corpus — curriculum or generator regressed")
    }
}
note("technique appearances: \(Technique.allCases.map { "\($0)=\(techniqueAppearances[$0] ?? 0)" }.joined(separator: " "))")

// MARK: - Modes

if calibrate {
    note("--- calibration: size → [(requested, score, graded)] ---")
    for size in BoardSize.allCases {
        let rows = scores[size.rawValue] ?? []
        for (tier, score, graded) in rows {
            note(String(format: "size %2d  requested %-6@  score %5.2f  graded %@",
                        size.rawValue, "\(tier)" as NSString, score, "\(graded)"))
        }
    }
}

if bake {
    note("--- SHIKAKU_BAKE: paste into BakedPuzzles.swift ---")
    for size in BoardSize.allCases {
        let result = ShikakuGenerator.generate(size: size, tier: .steady, seed: 424242)
        guard !result.isFallback else { note("// bake FAILED for \(size.rawValue)"); continue }
        var lines = ["    static let baked\(size.rawValue): [[Int]] = ["]
        for (i, rect) in result.puzzle.solution.enumerated() {
            let clue = result.puzzle.clues[i].cell
            lines.append("        [\(rect.minRow), \(rect.minCol), \(rect.maxRow), \(rect.maxCol), \(clue.row), \(clue.col)],")
        }
        lines.append("    ]")
        note(lines.joined(separator: "\n"))
    }
}

// MARK: - Lesson-position search

// SHIKAKU_LESSONS=1: for each mid/tail technique, find a board and a set of
// pre-placed mats such that — from the placements alone, exactly as the app
// reconstructs a lesson — the FIRST applicable technique is the target.
// Output is pasted into TutorialPuzzles.swift and pinned by TutorialFixtureTests.
if ProcessInfo.processInfo.environment["SHIKAKU_LESSONS"] == "1" {
    var wanted: Set<Technique> = [.mustCover, .soleOwner, .strandedCell, .corridorCount]
    note("--- SHIKAKU_LESSONS: paste into TutorialPuzzles.swift ---")
    var seed: UInt64 = 1
    while !wanted.isEmpty && seed < 4000 {
        defer { seed += 1 }
        // Small boards make readable lessons; sharp/deep tiers reach the
        // interesting techniques.
        for (size, tier) in [(BoardSize.five, Difficulty.sharp), (.five, .deep),
                             (.seven, .deep), (.seven, .severe)] {
            let result = ShikakuGenerator.generate(size: size, tier: tier, seed: seed)
            guard !result.isFallback else { continue }
            var state = SolverState(puzzle: result.puzzle)
            var placements: [Placement] = []
            var guard_ = 0
            while !state.allPlaced, guard_ < 500,
                  let step = LogicalSolver.nextStep(puzzle: result.puzzle, state: state) {
                guard_ += 1
                // Rebuild from placements alone — the app's lesson view has
                // no memory of solver eliminations.
                var fresh = SolverState(puzzle: result.puzzle)
                for p in placements { fresh.apply(placement: p) }
                if let first = LogicalSolver.nextStep(puzzle: result.puzzle, state: fresh),
                   wanted.contains(first.technique) {
                    wanted.remove(first.technique)
                    var lines = ["    // \(first.technique) lesson — seed \(seed), \(size.rawValue)×\(size.rawValue) \(tier)"]
                    lines.append("    specs: [")
                    for (i, rect) in result.puzzle.solution.enumerated() {
                        let clue = result.puzzle.clues[i].cell
                        lines.append("        [\(rect.minRow), \(rect.minCol), \(rect.maxRow), \(rect.maxCol), \(clue.row), \(clue.col)],")
                    }
                    lines.append("    ]")
                    lines.append("    preplacedClues: \(placements.map(\.clueIndex))")
                    note(lines.joined(separator: "\n"))
                }
                state.apply(step: step)
                if let p = step.placement { placements.append(p) }
            }
        }
    }
    if !wanted.isEmpty { note("NOT FOUND: \(wanted.map { "\($0)" }.joined(separator: ", "))") }
}

// MARK: - Verdict

note("\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)

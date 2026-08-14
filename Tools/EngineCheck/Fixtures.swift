//
//  Fixtures.swift
//  EngineCheck
//
//  Hand-authored boards that pin detector behaviour. Each fixture states
//  which technique MUST fire first — a spurious hint teaches something
//  false, which is worse than no hint.
//
//  Specs are flat [Int] rows — [r0, c0, r1, c1, clueRow, clueCol] — not
//  labeled tuples, for the type-checker budget (docs/ENGINEERING.md).
//

import Foundation

nonisolated struct TechniqueFixture {
    let name: String
    let puzzle: Puzzle
    let expectedFirst: Technique
    /// Expected placement of the first step, when it places.
    let expectedRect: GridRect?
}

nonisolated enum Fixtures {

    static var all: [TechniqueFixture] {
        var out: [TechniqueFixture] = []

        // A value-1 clue is present: oneCell must fire before anything else,
        // even though the 2-clues are prime with single fits.
        let oneCellSpecs: [[Int]] = [
            [0, 0, 0, 0, 0, 0],        // 1 at (0,0)
            [0, 1, 0, 2, 0, 2],        // 2 across the top
            [1, 0, 2, 2, 2, 0],        // 6 below
        ]
        out.append(TechniqueFixture(
            name: "oneCell fires first",
            puzzle: BakedPuzzles.build(3, oneCellSpecs),
            expectedFirst: .oneCell,
            expectedRect: GridRect(minRow: 0, minCol: 0, maxRow: 0, maxCol: 0)))

        // The vertical 3-strip is the only fit for the prime clue at (1,0):
        // its horizontal alternative would swallow the 6's clue at (1,2).
        let primeSpecs: [[Int]] = [
            [0, 0, 2, 0, 1, 0],        // 3 down the left, clue mid-strip
            [0, 1, 2, 2, 1, 2],        // 6 filling the rest
        ]
        out.append(TechniqueFixture(
            name: "primeStrip fires on the blocked prime",
            puzzle: BakedPuzzles.build(3, primeSpecs),
            expectedFirst: .primeStrip,
            expectedRect: GridRect(minRow: 0, minCol: 0, maxRow: 2, maxCol: 0)))

        // Four 4-clues in the corners; each has exactly one fit (the strips
        // are blocked by neighbouring clues) and none is prime, so onlyFit —
        // not primeStrip — must be the label.
        let onlyFitSpecs: [[Int]] = [
            [0, 0, 1, 1, 0, 0],
            [0, 2, 1, 3, 0, 3],
            [2, 0, 3, 1, 3, 0],
            [2, 2, 3, 3, 3, 3],
        ]
        out.append(TechniqueFixture(
            name: "onlyFit fires on the cornered square",
            puzzle: BakedPuzzles.build(4, onlyFitSpecs),
            expectedFirst: .onlyFit,
            expectedRect: GridRect(minRow: 0, minCol: 0, maxRow: 1, maxCol: 1)))

        return out
    }
}

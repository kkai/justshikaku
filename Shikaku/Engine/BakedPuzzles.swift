//
//  BakedPuzzles.swift
//  Shikaku
//
//  Pre-verified fallback boards for the budget-exhausted generation path.
//  The EngineCheck harness re-proves every board here unique and
//  LogicalSolver-solvable on every run — a fallback that searches is the
//  wrong tool, and a fallback that guesses is worse.
//
//  Boards are frozen literals produced by `SHIKAKU_BAKE=1 /tmp/enginecheck`,
//  which generates from fixed seeds and prints this file's tables. Re-bake
//  whenever the harness's baked-puzzle proof fails after an engine change.
//
//  Specs are flat [Int] rows — [r0, c0, r1, c1, clueRow, clueCol] — rather
//  than labeled tuples: the tuple-literal tables blew the SwiftUI-era
//  type-checker budget (see docs/ENGINEERING.md).
//

import Foundation

nonisolated enum BakedPuzzles {

    static func puzzle(size: BoardSize) -> Puzzle {
        switch size {
        case .five: build(5, five)
        case .seven: build(7, seven)
        case .ten: build(10, ten)
        case .twelve: build(12, twelve)
        }
    }

    static func build(_ size: Int, _ specs: [[Int]]) -> Puzzle {
        var solution: [GridRect] = []
        var clues: [Clue] = []
        for s in specs {
            let rect = GridRect(minRow: s[0], minCol: s[1], maxRow: s[2], maxCol: s[3])
            solution.append(rect)
            clues.append(Clue(cell: Cell(row: s[4], col: s[5]), value: rect.area))
        }
        return Puzzle(size: size, clues: clues, solution: solution)
    }

    // Baked 2026-08-13 via SHIKAKU_BAKE=1, seed 424242, tier steady.

    static let five: [[Int]] = [
        [0, 0, 2, 1, 2, 0],
        [0, 2, 4, 2, 4, 2],
        [0, 3, 0, 4, 0, 3],
        [1, 3, 4, 4, 1, 3],
        [3, 0, 4, 1, 3, 0],
    ]

    static let seven: [[Int]] = [
        [0, 0, 4, 0, 4, 0],
        [0, 1, 4, 1, 1, 1],
        [0, 2, 2, 3, 0, 2],
        [0, 4, 4, 4, 0, 4],
        [0, 5, 3, 5, 0, 5],
        [0, 6, 6, 6, 1, 6],
        [3, 2, 5, 2, 4, 2],
        [3, 3, 6, 3, 5, 3],
        [4, 5, 6, 5, 4, 5],
        [5, 0, 6, 1, 6, 1],
        [5, 4, 6, 4, 6, 4],
        [6, 2, 6, 2, 6, 2],
    ]

    static let ten: [[Int]] = [
        [0, 0, 3, 0, 2, 0],
        [0, 1, 0, 5, 0, 2],
        [0, 6, 7, 6, 6, 6],
        [0, 7, 6, 7, 0, 7],
        [0, 8, 5, 8, 2, 8],
        [0, 9, 5, 9, 2, 9],
        [1, 1, 1, 3, 1, 3],
        [1, 4, 3, 4, 1, 4],
        [1, 5, 8, 5, 6, 5],
        [2, 1, 3, 3, 2, 3],
        [4, 0, 5, 2, 5, 1],
        [4, 3, 7, 4, 7, 4],
        [6, 0, 8, 1, 7, 0],
        [6, 2, 8, 2, 7, 2],
        [6, 8, 9, 9, 7, 8],
        [7, 7, 9, 7, 9, 7],
        [8, 3, 8, 4, 8, 4],
        [8, 6, 9, 6, 9, 6],
        [9, 0, 9, 3, 9, 0],
        [9, 4, 9, 5, 9, 5],
    ]

    static let twelve: [[Int]] = [
        [0, 0, 3, 1, 1, 0],
        [0, 2, 0, 8, 0, 8],
        [0, 9, 3, 10, 3, 10],
        [0, 11, 6, 11, 5, 11],
        [1, 2, 4, 3, 3, 2],
        [1, 4, 5, 4, 3, 4],
        [1, 5, 5, 5, 2, 5],
        [1, 6, 4, 7, 1, 7],
        [1, 8, 2, 8, 1, 8],
        [3, 8, 8, 8, 5, 8],
        [4, 0, 6, 1, 6, 1],
        [4, 9, 7, 9, 5, 9],
        [4, 10, 11, 10, 10, 10],
        [5, 2, 8, 2, 6, 2],
        [5, 3, 9, 3, 5, 3],
        [5, 6, 8, 7, 7, 7],
        [6, 4, 10, 4, 6, 4],
        [6, 5, 11, 5, 9, 5],
        [7, 0, 10, 1, 8, 1],
        [7, 11, 11, 11, 11, 11],
        [8, 9, 10, 9, 9, 9],
        [9, 2, 11, 2, 9, 2],
        [9, 6, 9, 7, 9, 7],
        [9, 8, 10, 8, 10, 8],
        [10, 3, 11, 3, 10, 3],
        [10, 6, 11, 7, 10, 7],
        [11, 0, 11, 1, 11, 1],
        [11, 4, 11, 4, 11, 4],
        [11, 8, 11, 9, 11, 8],
    ]
}

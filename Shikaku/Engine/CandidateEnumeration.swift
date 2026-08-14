//
//  CandidateEnumeration.swift
//  Shikaku
//
//  The engine's foundation: a candidate for clue i is a rectangle with
//  area == value, inside the grid, containing clue i and no other clue.
//  Enumerated once per puzzle in deterministic order (shape, then position);
//  candidate lists only ever shrink from there.
//
//  This is the correctness lynchpin — the analogue of the siblings'
//  combination tables. It is differentially tested against brute force in
//  the EngineCheck harness; being wrong here corrupts difficulty ratings,
//  hints, and generation at once.
//

import Foundation

nonisolated enum Candidates {

    /// All legal rectangles for every clue, indexed by clue.
    static func enumerate(for puzzle: Puzzle) -> [[GridRect]] {
        puzzle.clues.indices.map { rects(forClue: $0, in: puzzle) }
    }

    /// Deterministic order: divisor height ascending, then top row, then left column.
    static func rects(forClue index: Int, in puzzle: Puzzle) -> [GridRect] {
        let clue = puzzle.clues[index]
        let size = puzzle.size
        var out: [GridRect] = []
        var h = 1
        while h <= min(clue.value, size) {
            defer { h += 1 }
            guard clue.value % h == 0 else { continue }
            let w = clue.value / h
            guard w <= size else { continue }
            let rowLo = max(0, clue.cell.row - h + 1)
            let rowHi = min(clue.cell.row, size - h)
            guard rowLo <= rowHi else { continue }
            let colLo = max(0, clue.cell.col - w + 1)
            let colHi = min(clue.cell.col, size - w)
            guard colLo <= colHi else { continue }
            for r0 in rowLo...rowHi {
                for c0 in colLo...colHi {
                    let rect = GridRect(minRow: r0, minCol: c0, maxRow: r0 + h - 1, maxCol: c0 + w - 1)
                    if !containsForeignClue(rect, excluding: index, in: puzzle) {
                        out.append(rect)
                    }
                }
            }
        }
        return out
    }

    static func containsForeignClue(_ rect: GridRect, excluding index: Int, in puzzle: Puzzle) -> Bool {
        for (i, other) in puzzle.clues.enumerated() where i != index {
            if rect.contains(other.cell) { return true }
        }
        return false
    }

    /// Brute-force enumeration for differential testing only: every rectangle
    /// in the grid, filtered by the candidate definition. O(size⁴) — never
    /// call outside tests.
    static func bruteForceRects(forClue index: Int, in puzzle: Puzzle) -> [GridRect] {
        let clue = puzzle.clues[index]
        var out: [GridRect] = []
        for r0 in 0..<puzzle.size {
            for c0 in 0..<puzzle.size {
                for r1 in r0..<puzzle.size {
                    for c1 in c0..<puzzle.size {
                        let rect = GridRect(minRow: r0, minCol: c0, maxRow: r1, maxCol: c1)
                        guard rect.area == clue.value,
                              rect.contains(clue.cell),
                              !containsForeignClue(rect, excluding: index, in: puzzle)
                        else { continue }
                        out.append(rect)
                    }
                }
            }
        }
        return out
    }
}

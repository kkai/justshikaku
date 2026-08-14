//
//  BacktrackingSolver.swift
//  Shikaku
//
//  Uniqueness proof ONLY — `countSolutions(limit: 2)`. Never a hint source;
//  the human argument lives in LogicalSolver. The hot path is allocation-free
//  on purpose: a sibling measured arrays/filter/reduce here at ~7µs/node
//  against ~1µs for index bookkeeping.
//

import Foundation

nonisolated struct BacktrackingSolver {

    /// Counts solutions up to `limit`, spending from `budget` (nodes).
    /// Returns nil if the budget ran out before the count was decided —
    /// callers must treat that as "unknown", never as a count.
    static func countSolutions(puzzle: Puzzle, limit: Int, budget: inout Int) -> Int? {
        let all = Candidates.enumerate(for: puzzle)
        let clueCount = puzzle.clues.count
        guard clueCount > 0 else { return 0 }
        // Sum of clue values must equal the grid area or no full cover exists.
        guard puzzle.clues.reduce(0, { $0 + $1.value }) == puzzle.size * puzzle.size else {
            return 0
        }

        // Flat candidate storage with liveness flags; undo via a trail stack.
        var rects: [GridRect] = []
        var offsets: [Int] = [0]
        for list in all {
            rects.append(contentsOf: list)
            offsets.append(rects.count)
        }
        var alive = [Bool](repeating: true, count: rects.count)
        var liveCount = (0..<clueCount).map { offsets[$0 + 1] - offsets[$0] }
        var placed = [Int](repeating: -1, count: clueCount) // index into rects
        var trail: [Int] = []   // killed candidate indices, per-frame marks below
        var found = 0

        func kill(_ idx: Int, ofClue clue: Int) {
            alive[idx] = false
            liveCount[clue] -= 1
            trail.append(idx)
        }

        func clue(of idx: Int) -> Int {
            // Binary search over offsets.
            var lo = 0, hi = clueCount - 1
            while lo < hi {
                let mid = (lo + hi + 1) / 2
                if offsets[mid] <= idx { lo = mid } else { hi = mid - 1 }
            }
            return lo
        }

        func search(_ depth: Int, budget: inout Int) -> Bool {
            // Returns true when the caller should stop (limit hit or budget out).
            if budget <= 0 { return true }
            budget -= 1

            if depth == clueCount {
                found += 1
                return found >= limit
            }

            // MRV: unplaced clue with the fewest live candidates.
            var target = -1
            var best = Int.max
            for i in 0..<clueCount where placed[i] < 0 {
                if liveCount[i] < best { best = liveCount[i]; target = i }
                if best == 0 { return false } // dead branch
            }

            for idx in offsets[target]..<offsets[target + 1] where alive[idx] {
                let rect = rects[idx]
                let mark = trail.count
                placed[target] = idx
                // Prune every other clue's overlapping candidates.
                var contradiction = false
                for j in 0..<clueCount where j != target && placed[j] < 0 {
                    for k in offsets[j]..<offsets[j + 1] where alive[k] && rects[k].overlaps(rect) {
                        kill(k, ofClue: j)
                    }
                    if liveCount[j] == 0 { contradiction = true; break }
                }
                if !contradiction {
                    if search(depth + 1, budget: &budget) { return true }
                }
                // Undo.
                while trail.count > mark {
                    let k = trail.removeLast()
                    alive[k] = true
                    liveCount[clue(of: k)] += 1
                }
                placed[target] = -1
            }
            return false
        }

        let stopped = search(0, budget: &budget)
        if stopped && budget <= 0 && found < limit {
            return nil
        }
        return found
    }
}

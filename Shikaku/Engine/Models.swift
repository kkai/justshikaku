//
//  Models.swift
//  Shikaku
//
//  Core value types. Everything here is `nonisolated` + `Sendable` — the
//  engine compiles as a CLI (see Tools/EngineCheck) and generation runs
//  off-main. No SwiftUI or UIKit imports, ever.
//

import Foundation

nonisolated struct Cell: Hashable, Codable, Sendable, Comparable {
    let row: Int
    let col: Int

    // Reading order. Deterministic ordering matters wherever iteration order
    // is observable (outline seeds, candidate order) — Dictionary order is not.
    static func < (a: Cell, b: Cell) -> Bool {
        a.row != b.row ? a.row < b.row : a.col < b.col
    }
}

/// A rectangle of cells, closed on both ends.
nonisolated struct GridRect: Hashable, Codable, Sendable {
    let minRow: Int
    let minCol: Int
    let maxRow: Int
    let maxCol: Int

    init(minRow: Int, minCol: Int, maxRow: Int, maxCol: Int) {
        self.minRow = minRow
        self.minCol = minCol
        self.maxRow = maxRow
        self.maxCol = maxCol
    }

    init(origin: Cell, width: Int, height: Int) {
        self.init(minRow: origin.row, minCol: origin.col,
                  maxRow: origin.row + height - 1, maxCol: origin.col + width - 1)
    }

    var width: Int { maxCol - minCol + 1 }
    var height: Int { maxRow - minRow + 1 }
    var area: Int { width * height }

    func contains(_ c: Cell) -> Bool {
        c.row >= minRow && c.row <= maxRow && c.col >= minCol && c.col <= maxCol
    }

    func overlaps(_ o: GridRect) -> Bool {
        minRow <= o.maxRow && o.minRow <= maxRow && minCol <= o.maxCol && o.minCol <= maxCol
    }

    /// Intersection, or nil when disjoint.
    func intersection(_ o: GridRect) -> GridRect? {
        let r0 = max(minRow, o.minRow), c0 = max(minCol, o.minCol)
        let r1 = min(maxRow, o.maxRow), c1 = min(maxCol, o.maxCol)
        guard r0 <= r1 && c0 <= c1 else { return nil }
        return GridRect(minRow: r0, minCol: c0, maxRow: r1, maxCol: c1)
    }

    /// Row-major, deterministic.
    var cells: [Cell] {
        var out: [Cell] = []
        out.reserveCapacity(area)
        for r in minRow...maxRow {
            for c in minCol...maxCol { out.append(Cell(row: r, col: c)) }
        }
        return out
    }
}

nonisolated struct Clue: Hashable, Codable, Sendable {
    let cell: Cell
    let value: Int
}

nonisolated struct Puzzle: Codable, Sendable, Equatable {
    /// Square boards in v1.
    let size: Int
    /// A clue's index in this array is its identity everywhere in the engine.
    let clues: [Clue]
    /// solution[i] is clue i's rectangle.
    let solution: [GridRect]

    func inBounds(_ rect: GridRect) -> Bool {
        rect.minRow >= 0 && rect.minCol >= 0 && rect.maxRow < size && rect.maxCol < size
    }

    /// Index of the clue at a cell, if any.
    func clueIndex(at cell: Cell) -> Int? {
        clues.firstIndex { $0.cell == cell }
    }
}

/// A rectangle the player has committed. The gesture layer guarantees exactly
/// one clue inside, so `clueIndex` is non-optional.
nonisolated struct PlacedRect: Hashable, Codable, Sendable {
    var rect: GridRect
    var clueIndex: Int
}

/// The player's board. `claims` are hint-applied "this cell belongs to clue k"
/// marks — Shikaku's pencil-mark analogue. They make elimination-only hint
/// steps visibly apply, and they survive undo like any board change.
nonisolated struct BoardState: Codable, Sendable, Equatable {
    var placed: [PlacedRect] = []
    var claims: [Cell: Int] = [:]

    func coveringRect(of cell: Cell) -> PlacedRect? {
        placed.first { $0.rect.contains(cell) }
    }
}

/// Fixed-size bitset over clue indices. Two words support 128 clues; a 12×12
/// board tops out near 40. This is the analogue of the family's UInt16 digit
/// mask and powers reach analysis without allocation.
nonisolated struct ClueMask: Sendable, Equatable {
    var lo: UInt64 = 0
    var hi: UInt64 = 0

    static let maxClues = 128

    mutating func insert(_ i: Int) {
        if i < 64 { lo |= 1 << UInt64(i) } else { hi |= 1 << UInt64(i - 64) }
    }

    func contains(_ i: Int) -> Bool {
        i < 64 ? (lo >> UInt64(i)) & 1 == 1 : (hi >> UInt64(i - 64)) & 1 == 1
    }

    var count: Int { lo.nonzeroBitCount + hi.nonzeroBitCount }

    /// The single member when `count == 1`, else nil.
    var only: Int? {
        guard count == 1 else { return nil }
        return lo != 0 ? lo.trailingZeroBitCount : 64 + hi.trailingZeroBitCount
    }

    var isEmpty: Bool { lo == 0 && hi == 0 }
}

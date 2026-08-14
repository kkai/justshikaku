//
//  BoardGeometry.swift
//  Shikaku
//
//  One source of truth for where everything on the board sits — ported from
//  the family. Every layer (lattice, mats, outlines, clue numerals, the drag
//  preview, and the hint's drawn argument) positions against this single
//  struct; mixing absolute geometry with stack-laid cells needed half-point
//  fudges in a legacy sibling and is not repeated here.
//

import SwiftUI

nonisolated struct BoardGeometry: Equatable, Sendable {
    let size: Int
    let cellSize: CGFloat
    let origin: CGPoint

    /// Fits a `size × size` board inside `container`, centred.
    ///
    /// `cellSize` is floored to a whole point: fractional cell sizes put seams
    /// between cells on some scales and not others, which reads as a rendering
    /// bug. The cap keeps small boards from ballooning until they stop reading
    /// as a room.
    init(size: Int, container: CGSize, maxCellSize: CGFloat = 64) {
        self.size = max(size, 1)
        let available = min(container.width, container.height)
        let fitted = (available / CGFloat(self.size)).rounded(.down)
        self.cellSize = max(min(fitted, maxCellSize), 1)

        let board = self.cellSize * CGFloat(self.size)
        self.origin = CGPoint(
            x: ((container.width - board) / 2).rounded(),
            y: ((container.height - board) / 2).rounded()
        )
    }

    var boardLength: CGFloat { cellSize * CGFloat(size) }

    var boardRect: CGRect {
        CGRect(x: origin.x, y: origin.y, width: boardLength, height: boardLength)
    }

    func rect(for cell: Cell) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(cell.col) * cellSize,
            y: origin.y + CGFloat(cell.row) * cellSize,
            width: cellSize,
            height: cellSize
        )
    }

    func rect(for gridRect: GridRect) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(gridRect.minCol) * cellSize,
            y: origin.y + CGFloat(gridRect.minRow) * cellSize,
            width: CGFloat(gridRect.width) * cellSize,
            height: CGFloat(gridRect.height) * cellSize
        )
    }

    func center(for cell: Cell) -> CGPoint {
        let r = rect(for: cell)
        return CGPoint(x: r.midX, y: r.midY)
    }

    /// The cell under a point, or nil outside the board.
    func cell(at point: CGPoint) -> Cell? {
        guard boardRect.contains(point) else { return nil }
        let col = Int((point.x - origin.x) / cellSize)
        let row = Int((point.y - origin.y) / cellSize)
        guard row >= 0, row < size, col >= 0, col < size else { return nil }
        return Cell(row: row, col: col)
    }

    /// The nearest cell to a point — a drag that leaves the board pins to the
    /// border row/column rather than cancelling.
    func clampedCell(at point: CGPoint) -> Cell {
        let col = Int(((point.x - origin.x) / cellSize).rounded(.down))
        let row = Int(((point.y - origin.y) / cellSize).rounded(.down))
        return Cell(row: min(max(row, 0), size - 1),
                    col: min(max(col, 0), size - 1))
    }

    // MARK: - Derived type sizes

    /// Clue numerals are the board's only text; they scale with the cell.
    var clueSize: CGFloat { max(cellSize * 0.42, 10) }
    /// The live area badge on the drag preview.
    var badgeSize: CGFloat { max(cellSize * 0.34, 11) }
}

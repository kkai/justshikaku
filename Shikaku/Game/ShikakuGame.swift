//
//  ShikakuGame.swift
//  Shikaku
//
//  The live game: board state, the drag-to-draw gesture's state machine,
//  undo, errors, and win detection. A service the views read — not a
//  ViewModel; views own their own presentation state.
//

import SwiftUI

@Observable @MainActor
final class ShikakuGame {

    // MARK: - Identity

    let puzzle: Puzzle
    let size: BoardSize
    let difficulty: Difficulty
    /// Set when this game is the daily room. A daily never touches the
    /// single save slot and records into the streak instead of best times.
    let dailyDay: DayKey?

    private(set) var board = BoardState()
    private(set) var elapsedSeconds: Int
    private(set) var hintsUsed: Int
    var isTimerRunning = true

    /// Clues credited toward mastery. Survives undo deliberately —
    /// place/undo/place is indistinguishable from a fresh deduction, so
    /// clearing this would let a technique be farmed to Learned.
    private(set) var creditedClues: Set<Int> = []

    init(puzzle: Puzzle, size: BoardSize, difficulty: Difficulty,
         board: BoardState = BoardState(), elapsedSeconds: Int = 0, hintsUsed: Int = 0,
         dailyDay: DayKey? = nil) {
        self.puzzle = puzzle
        self.size = size
        self.difficulty = difficulty
        self.board = board
        self.elapsedSeconds = elapsedSeconds
        self.hintsUsed = hintsUsed
        self.dailyDay = dailyDay
    }

    // MARK: - Drag state

    /// The sumitsubo line while the finger is down.
    struct DragPreview: Equatable {
        var rect: GridRect
        /// The single clue inside, when there is exactly one.
        var clueIndex: Int?
        /// Number of clues swept — 0 or 2+ means the release will reject.
        var clueCount: Int
        /// Cells that would collide with an existing mat (shown hatched;
        /// commit removes those mats — redraw-over is the standard fluid
        /// Shikaku interaction and doubles as resize).
        var conflictCells: [Cell]
    }

    private(set) var dragAnchor: Cell?
    private(set) var preview: DragPreview?
    /// Set for one animation beat when a drag is rejected.
    private(set) var rejectedPreview: GridRect?

    /// The mastery tracker, injected by the hosting view (services come via
    /// @Environment and views hand them down; the game never looks one up).
    /// nil in lessons and previews, where no credit should accrue.
    var mastery: MasteryTracker?
    /// Set for the duration of a hint-applied placement, so applied moves
    /// can never claim unaided credit.
    private var applyingHint = false

    /// The live hint, if the player asked for one. Lives here rather than in
    /// a view because the board's ArgumentOverlay draws it against
    /// BoardGeometry. Any committed mat dismisses it — the board moved on.
    var activeHint: Hint?

    func dragChanged(anchor: Cell, current cell: Cell) {
        if dragAnchor == nil {
            dragAnchor = anchor
        }
        guard let anchor = dragAnchor else { return }
        let rect = GridRect(
            minRow: min(anchor.row, cell.row), minCol: min(anchor.col, cell.col),
            maxRow: max(anchor.row, cell.row), maxCol: max(anchor.col, cell.col))
        if rect == preview?.rect { return }

        let previousArea = preview?.rect.area
        let inside = puzzle.clues.enumerated().filter { rect.contains($0.element.cell) }
        let conflicts = board.placed
            .filter { $0.rect.overlaps(rect) }
            .flatMap { placed in placed.rect.cells.filter { rect.contains($0) } }
        preview = DragPreview(
            rect: rect,
            clueIndex: inside.count == 1 ? inside[0].offset : nil,
            clueCount: inside.count,
            conflictCells: conflicts)
        if let previousArea, previousArea != rect.area {
            Haptics.previewTick()
        }
    }

    func dragEnded() {
        defer { dragAnchor = nil; preview = nil }
        guard let anchor = dragAnchor, let preview else { return }

        // Tap semantics: the finger never left its cell.
        if preview.rect.area == 1 {
            tap(at: anchor)
            return
        }

        // Commit semantics: exactly one clue makes a meaningful mat — wrong
        // AREA still commits and shows as a conflict (the error hint tier
        // needs something to point at); zero or 2+ clues never means anything
        // and is rejected outright.
        guard let clueIndex = preview.clueIndex else {
            rejectedPreview = preview.rect
            Haptics.reject()
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(350))
                self?.rejectedPreview = nil
            }
            return
        }
        commit(PlacedRect(rect: preview.rect, clueIndex: clueIndex))
    }

    func dragCancelled() {
        dragAnchor = nil
        preview = nil
    }

    private func tap(at cell: Cell) {
        // Inside a committed mat → lift it off the board.
        if let covering = board.coveringRect(of: cell) {
            remove(covering)
            return
        }
        // On a bare clue with exactly one geometric fit left → auto-place.
        // This is the remove-busywork move: pure geometry against committed
        // mats, never solver eliminations — those must be earned or hinted.
        if let clueIndex = puzzle.clueIndex(at: cell) {
            let fits = geometricFits(forClue: clueIndex)
            if fits.count == 1 {
                commit(PlacedRect(rect: fits[0], clueIndex: clueIndex))
            }
        }
    }

    /// Candidates for a clue that don't cross an existing mat.
    func geometricFits(forClue index: Int) -> [GridRect] {
        Candidates.rects(forClue: index, in: puzzle).filter { rect in
            !board.placed.contains { $0.rect.overlaps(rect) }
        }
    }

    // MARK: - Mutation + undo

    private enum Op {
        case commit(added: PlacedRect, removed: [PlacedRect])
        case remove(PlacedRect)
        case claim(cell: Cell, clueIndex: Int)
    }

    private var undoStack: [Op] = []
    var canUndo: Bool { !undoStack.isEmpty }

    private func commit(_ placed: PlacedRect) {
        // The deduction is judged against the board BEFORE this mat lands.
        let priorBoard = board
        // Redraw-over: mats the new one overlaps come off first. A second mat
        // for the same clue also replaces the old one.
        let displaced = board.placed.filter {
            $0.rect.overlaps(placed.rect) || $0.clueIndex == placed.clueIndex
        }
        board.placed.removeAll {
            $0.rect.overlaps(placed.rect) || $0.clueIndex == placed.clueIndex
        }
        board.placed.append(placed)
        // A mat supersedes any claim marks under it.
        board.claims = board.claims.filter { !placed.rect.contains($0.key) }
        undoStack.append(.commit(added: placed, removed: displaced))
        activeHint = nil
        Haptics.matSettle()
        creditIfDeduced(placed, priorBoard: priorBoard)
        if isSolved { finishIfSolved() }
    }

    /// The unaided-mastery contract, finally wired: a correct placement the
    /// player laid without a hint, which the solver can independently derive
    /// from the position it was laid in, credits the hardest technique in
    /// that derivation. `creditedClues` survives undo (anti-farming), and
    /// hint-applied placements are excluded at the source.
    private func creditIfDeduced(_ placed: PlacedRect, priorBoard: BoardState) {
        guard let mastery, !applyingHint else { return }
        guard !areaConflict(placed), !isWrong(placed) else { return }
        guard claimMasteryCredit(forClue: placed.clueIndex) else { return }
        let state = SolverState(puzzle: puzzle, board: priorBoard)
        guard let chain = LogicalSolver.chain(
            toPlace: placed.clueIndex, puzzle: puzzle, state: state) else { return }
        mastery.recordUnaidedPlacement(chain: chain)
    }

    private func remove(_ placed: PlacedRect) {
        board.placed.removeAll { $0 == placed }
        undoStack.append(.remove(placed))
        Haptics.matRemove()
    }

    /// Error-hint resolutions lift the wrong mat through the same undoable
    /// path a tap uses.
    func undoableRemove(_ placed: PlacedRect) {
        remove(placed)
    }

    /// Hint resolutions come through here so claims materialise visibly.
    func applyHintClaim(cell: Cell, clueIndex: Int) {
        board.claims[cell] = clueIndex
        undoStack.append(.claim(cell: cell, clueIndex: clueIndex))
    }

    func applyHintPlacement(_ placement: Placement) {
        applyingHint = true
        defer { applyingHint = false }
        // Applied placements still burn the clue's credit: place-by-hint,
        // undo, place-by-hand must not read as a fresh deduction.
        _ = claimMasteryCredit(forClue: placement.clueIndex)
        commit(PlacedRect(rect: placement.rect, clueIndex: placement.clueIndex))
    }

    func undo() {
        guard let op = undoStack.popLast() else { return }
        switch op {
        case .commit(let added, let removed):
            board.placed.removeAll { $0 == added }
            board.placed.append(contentsOf: removed)
        case .remove(let placed):
            board.placed.append(placed)
        case .claim(let cell, _):
            board.claims.removeValue(forKey: cell)
        }
    }

    // MARK: - Judgement

    /// Rule-level conflict: the mat's area disagrees with its clue. Always
    /// visible (red have/need badge) regardless of the error setting.
    func areaConflict(_ placed: PlacedRect) -> Bool {
        placed.rect.area != puzzle.clues[placed.clueIndex].value
    }

    /// Solution-level error: locally legal but wrong. These are the mistakes
    /// that let a player drift twenty moves — surfaced only when the error
    /// feedback setting is on, and always to the hint engine.
    func isWrong(_ placed: PlacedRect) -> Bool {
        placed.rect != puzzle.solution[placed.clueIndex]
    }

    var wrongPlacements: [PlacedRect] {
        board.placed.filter { isWrong($0) }
    }

    /// Solved = every clue housed in a mat of its exact area, no overlaps,
    /// no gaps. With a unique solution this is equality with it.
    var isSolved: Bool {
        guard board.placed.count == puzzle.clues.count else { return false }
        return board.placed.allSatisfy { $0.rect == puzzle.solution[$0.clueIndex] }
    }

    var isClueSatisfied: [Bool] {
        var satisfied = [Bool](repeating: false, count: puzzle.clues.count)
        for placed in board.placed where !areaConflict(placed) {
            satisfied[placed.clueIndex] = true
        }
        return satisfied
    }

    private(set) var didWin = false

    private func finishIfSolved() {
        guard !didWin else { return }
        didWin = true
        isTimerRunning = false
        Haptics.win()
    }

    // MARK: - Mastery

    /// The caller declares `unaided` — a placement applied from a hint is
    /// indistinguishable from a reasoned one once it is on the board, so
    /// GameView combines `!appliedHint && claimMasteryCredit(...)`.
    func claimMasteryCredit(forClue index: Int) -> Bool {
        guard !creditedClues.contains(index) else { return false }
        creditedClues.insert(index)
        return true
    }

    func recordHintUsed() {
        hintsUsed += 1
    }

    func tickSecond() {
        if isTimerRunning && !didWin { elapsedSeconds += 1 }
    }

    // MARK: - Snapshot

    var snapshot: GameSnapshot {
        GameSnapshot(puzzle: puzzle, board: board,
                     elapsedSeconds: elapsedSeconds,
                     sizeRaw: size.rawValue, difficultyRaw: difficulty.rawValue,
                     hintsUsed: hintsUsed)
    }
}

//
//  TutorialPuzzles.swift
//  Shikaku
//
//  Hand-authored and engine-found lesson boards. The early lessons use tiny
//  hand boards; the mid/tail lessons are REAL generated positions found by
//  `SHIKAKU_LESSONS=1 /tmp/enginecheck` — a board plus pre-laid mats such
//  that, from the placements alone (exactly how a lesson reconstructs
//  state), the FIRST applicable technique is the lesson's subject.
//
//  Pinned by TutorialFixtureTests: if detector precedence changes and a
//  board stops exercising its technique, a test says so — not a player.
//

import Foundation

nonisolated struct LessonBoard: Sendable {
    let puzzle: Puzzle
    /// Clue indices whose solution mats are pre-laid when the lesson opens.
    let preplacedClues: [Int]

    var preplaced: [PlacedRect] {
        preplacedClues.map { PlacedRect(rect: puzzle.solution[$0], clueIndex: $0) }
    }

    var startingBoard: BoardState {
        BoardState(placed: preplaced, claims: [:])
    }
}

nonisolated enum TutorialPuzzles {

    /// The rules tutorial's board: a 3×3 with a 1, a 2, and a 6 — one tap,
    /// one small drag, one big drag, and the room is done.
    static let rules = LessonBoard(
        puzzle: BakedPuzzles.build(3, [
            [0, 0, 0, 0, 0, 0],
            [0, 1, 0, 2, 0, 2],
            [1, 0, 2, 2, 2, 0],
        ]),
        preplacedClues: [])

    static func lesson(for technique: Technique) -> LessonBoard {
        switch technique {
        case .oneCell:
            LessonBoard(
                puzzle: BakedPuzzles.build(3, [
                    [0, 0, 0, 0, 0, 0],
                    [0, 1, 0, 2, 0, 2],
                    [1, 0, 2, 2, 2, 0],
                ]),
                preplacedClues: [])
        case .primeStrip:
            LessonBoard(
                puzzle: BakedPuzzles.build(3, [
                    [0, 0, 2, 0, 1, 0],
                    [0, 1, 2, 2, 1, 2],
                ]),
                preplacedClues: [])
        case .onlyFit:
            LessonBoard(
                puzzle: BakedPuzzles.build(4, [
                    [0, 0, 1, 1, 0, 0],
                    [0, 2, 1, 3, 0, 3],
                    [2, 0, 3, 1, 3, 0],
                    [2, 2, 3, 3, 3, 3],
                ]),
                preplacedClues: [])
        case .mustCover:
            // Found by SHIKAKU_LESSONS — seed 1, 5×5 sharp.
            LessonBoard(
                puzzle: BakedPuzzles.build(5, [
                    [0, 0, 2, 0, 2, 0],
                    [0, 1, 2, 3, 2, 3],
                    [0, 4, 4, 4, 0, 4],
                    [3, 0, 3, 3, 3, 1],
                    [4, 0, 4, 2, 4, 2],
                    [4, 3, 4, 3, 4, 3],
                ]),
                preplacedClues: [5])
        case .soleOwner:
            // Found by SHIKAKU_LESSONS — seed 1, 5×5 deep. soleOwner is the
            // first move on the EMPTY board here, which makes a clean lesson.
            LessonBoard(
                puzzle: BakedPuzzles.build(5, [
                    [0, 0, 2, 1, 2, 1],
                    [0, 2, 4, 2, 0, 2],
                    [0, 3, 2, 4, 2, 3],
                    [3, 0, 4, 1, 3, 1],
                    [3, 3, 4, 4, 3, 3],
                ]),
                preplacedClues: [])
        case .strandedCell:
            // Found by SHIKAKU_LESSONS — seed 122, 5×5 deep.
            LessonBoard(
                puzzle: BakedPuzzles.build(5, [
                    [0, 0, 4, 0, 0, 0],
                    [0, 1, 3, 2, 1, 1],
                    [0, 3, 3, 3, 1, 3],
                    [0, 4, 2, 4, 2, 4],
                    [3, 4, 4, 4, 3, 4],
                    [4, 1, 4, 3, 4, 2],
                ]),
                preplacedClues: [])
        case .corridorCount:
            // Found by SHIKAKU_LESSONS — seed 3101, 7×7 severe.
            LessonBoard(
                puzzle: BakedPuzzles.build(7, [
                    [0, 0, 5, 0, 2, 0],
                    [0, 1, 0, 5, 0, 2],
                    [0, 6, 5, 6, 2, 6],
                    [1, 1, 5, 1, 2, 1],
                    [1, 2, 4, 4, 3, 3],
                    [1, 5, 5, 5, 2, 5],
                    [5, 2, 6, 3, 5, 3],
                    [5, 4, 6, 4, 5, 4],
                    [6, 0, 6, 1, 6, 1],
                    [6, 5, 6, 6, 6, 5],
                ]),
                preplacedClues: [4, 6])
        }
    }
}

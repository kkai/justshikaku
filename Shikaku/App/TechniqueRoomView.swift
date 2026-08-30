//
//  TechniqueRoomView.swift
//  Shikaku
//
//  "A room that needs it": a fresh full puzzle generated so one named
//  technique appears in its solve. Every competitor sells grid sizes; this
//  sells reasoning — and only an engine that classifies boards by their
//  logical solution can offer it.
//

import SwiftUI

/// Per-technique room plan: the earliest techniques get small gentle rooms,
/// the one-ply tail gets the deep end. Free sizes only, like the daily, so
/// no gate ever touches this path.
nonisolated enum TechniqueRoom {
    static func plan(for technique: Technique) -> (size: BoardSize, difficulty: Difficulty) {
        switch technique {
        case .oneCell, .primeStrip: (.five, .gentle)
        case .onlyFit: (.five, .steady)
        case .mustCover: (.seven, .steady)
        case .soleOwner: (.seven, .sharp)
        case .strandedCell, .corridorCount: (.seven, .severe)
        }
    }
}

/// Generates the room off-main behind the loading view, then hosts a normal
/// game tagged with the technique it was built around.
struct TechniqueRoomHostView: View {
    let technique: Technique
    let seed: UInt64

    @Environment(MasteryTracker.self) private var mastery
    @State private var game: ShikakuGame?

    var body: some View {
        Group {
            if let game {
                GameView(game: game)
            } else {
                PuzzleLoadingView()
            }
        }
        .task {
            guard game == nil else { return }
            let technique = technique
            let seed = seed
            let plan = TechniqueRoom.plan(for: technique)
            let outcome = await Task.detached(priority: .userInitiated) {
                ShikakuGenerator.generate(featuring: technique, size: plan.size,
                                          tier: plan.difficulty, seed: seed)
            }.value
            let fresh = ShikakuGame(
                puzzle: outcome.result.puzzle, size: plan.size,
                difficulty: plan.difficulty,
                // An unmatched fallback plays as a plain room — the header
                // must not promise a technique the board does not contain.
                featuring: outcome.matched ? technique : nil)
            fresh.mastery = mastery
            game = fresh
        }
    }
}

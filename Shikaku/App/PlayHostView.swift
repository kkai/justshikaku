//
//  PlayHostView.swift
//  Shikaku
//
//  Bridges "play at (size, tier)" to a live game: takes the cache's warm
//  puzzle when there is one, otherwise generates off-main behind the loading
//  screen. The loading screen should be the exception — PuzzleCache exists
//  so it usually is.
//

import SwiftUI

struct PlayHostView: View {
    let size: BoardSize
    let difficulty: Difficulty

    @Environment(PuzzleCache.self) private var cache
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
            // take() awaits a half-done warm rather than generating twice,
            // and generates fresh only when nothing is warm. nil = the
            // player backed out first.
            guard let result = await cache.take(size: size, tier: difficulty) else { return }
            let fresh = ShikakuGame(puzzle: result.puzzle, size: size, difficulty: difficulty)
            fresh.mastery = mastery
            game = fresh
        }
    }
}

/// Resolves the snapshot ONCE, on appear. Reading `progress.savedGame` inline
/// means winning — which clears the save — invalidates the destination and
/// swaps the live game out mid-celebration (a sibling shipped that).
struct ResumeGameView: View {
    @Environment(ProgressStore.self) private var progress
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
        .onAppear {
            guard game == nil, let saved = progress.savedGame else { return }
            let fresh = ShikakuGame(
                puzzle: saved.puzzle,
                size: BoardSize(rawValue: saved.sizeRaw) ?? .five,
                difficulty: Difficulty(rawValue: saved.difficultyRaw) ?? .gentle,
                board: saved.board,
                elapsedSeconds: saved.elapsedSeconds,
                hintsUsed: saved.hintsUsed)
            fresh.mastery = mastery
            game = fresh
        }
    }
}

struct PuzzleLoadingView: View {
    var body: some View {
        ZStack {
            Theme.floor.ignoresSafeArea()
            VStack(spacing: Layout.s3) {
                ProgressView()
                Text("Measuring the room…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }
}

//
//  ProofView.swift
//  Shikaku
//
//  The proof: your last finished room, replayed one mat at a time, with
//  each move checked against the solver. A move it can derive from the
//  position you played it in counts as deduced; a move a hint laid is
//  shown; a correct move it cannot derive is a leap. No other puzzle app
//  can tell you which of your own moves were reasoned, because no other
//  app's engine knows why a move is right.
//

import SwiftUI

/// One graded move of the replay.
nonisolated struct GradedMove: Sendable, Equatable {
    enum Verdict: Equatable {
        case deduced(Technique)
        case shown
        case leap
    }
    let move: ShikakuGame.SolveMove
    let verdict: Verdict
}

nonisolated enum SolveGrader {
    /// Replays the moves in commit order; each is judged against the board
    /// as it stood when the player laid it.
    static func grade(puzzle: Puzzle, moves: [ShikakuGame.SolveMove]) -> [GradedMove] {
        var graded: [GradedMove] = []
        for (index, move) in moves.enumerated() {
            if move.hinted {
                graded.append(GradedMove(move: move, verdict: .shown))
                continue
            }
            let prior = BoardState(
                placed: moves[0..<index].map {
                    PlacedRect(rect: $0.rect, clueIndex: $0.clueIndex)
                },
                claims: [:])
            let state = SolverState(puzzle: puzzle, board: prior)
            if let chain = LogicalSolver.chain(toPlace: move.clueIndex,
                                               puzzle: puzzle, state: state),
               let hardest = chain.max(by: { $0.weight < $1.weight }) {
                graded.append(GradedMove(move: move, verdict: .deduced(hardest)))
            } else {
                graded.append(GradedMove(move: move, verdict: .leap))
            }
        }
        return graded
    }

    static func counts(_ graded: [GradedMove]) -> (deduced: Int, shown: Int, leaps: Int) {
        var deduced = 0, shown = 0, leaps = 0
        for g in graded {
            switch g.verdict {
            case .deduced: deduced += 1
            case .shown: shown += 1
            case .leap: leaps += 1
            }
        }
        return (deduced, shown, leaps)
    }
}

/// The Home card. Appears once a finished room exists.
struct ProofCard: View {
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        if let solve = progress.lastSolve {
            Button {
                Haptics.previewTick()
                path.append(.proof)
            } label: {
                HStack(spacing: Layout.s4) {
                    BoardThumbnail(
                        puzzle: solve.puzzle,
                        board: BoardState(
                            placed: solve.moves.map {
                                PlacedRect(rect: $0.rect, clueIndex: $0.clueIndex)
                            },
                            claims: [:]))
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: Layout.s1) {
                        Text("Your last room")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        Text(summaryLine(solve))
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(Layout.s4)
                .homeCard()
            }
            .buttonStyle(.plain)
        }
    }

    private func summaryLine(_ solve: ProgressStore.LastSolve) -> String {
        let counts = SolveGrader.counts(
            SolveGrader.grade(puzzle: solve.puzzle, moves: solve.moves))
        var parts = ["\(counts.deduced) worked out"]
        if counts.shown > 0 { parts.append("\(counts.shown) from hints") }
        if counts.leaps > 0 { parts.append("\(counts.leaps) beyond the lessons") }
        return parts.joined(separator: " · ")
    }
}

/// The replay screen: step through your own solve, move by move.
struct ReplayView: View {
    @Environment(ProgressStore.self) private var progress

    @State private var graded: [GradedMove] = []
    @State private var step = 0
    @State private var solve: ProgressStore.LastSolve?

    var body: some View {
        ZStack {
            Theme.floor.ignoresSafeArea()
            if let solve {
                VStack(spacing: Layout.s4) {
                    header(solve)
                    Spacer(minLength: 0)
                    RoomBoard(game: stagedGame(solve))
                        .allowsHitTesting(false)
                    Spacer(minLength: 0)
                    verdictRail
                    controls
                }
                .padding(.vertical, Layout.s4)
            } else {
                Text("Finish a room and its replay appears here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .navigationTitle("Your last room")
        .modeGuide(.proof)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard graded.isEmpty, let solve = progress.lastSolve else { return }
            self.solve = solve
            let puzzle = solve.puzzle
            let moves = solve.moves
            graded = await Task.detached(priority: .userInitiated) {
                SolveGrader.grade(puzzle: puzzle, moves: moves)
            }.value
            step = graded.count
        }
    }

    private func header(_ solve: ProgressStore.LastSolve) -> some View {
        HStack {
            Text("\(BoardSize(rawValue: solve.sizeRaw)?.label ?? "") · \(TimeFormatting.clock(solve.seconds))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            Text("\(step) of \(graded.count)")
                .font(Theme.numberFont(size: 15))
                .foregroundStyle(Theme.inkSoft)
                .monospacedDigit()
        }
        .padding(.horizontal, Layout.s4)
    }

    /// The board as it stood after `step` moves.
    private func stagedGame(_ solve: ProgressStore.LastSolve) -> ShikakuGame {
        let placed = solve.moves.prefix(step).map {
            PlacedRect(rect: $0.rect, clueIndex: $0.clueIndex)
        }
        return ShikakuGame(
            puzzle: solve.puzzle,
            size: BoardSize(rawValue: solve.sizeRaw) ?? .five,
            difficulty: Difficulty(rawValue: solve.difficultyRaw) ?? .gentle,
            board: BoardState(placed: Array(placed), claims: [:]))
    }

    @ViewBuilder
    private var verdictRail: some View {
        if step > 0, step <= graded.count {
            let current = graded[step - 1]
            AnnotationRail(marked: isDeduced(current)) {
                Text(verdictLine(current))
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            AnnotationRail {
                Text("Step through the room you laid.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private func isDeduced(_ graded: GradedMove) -> Bool {
        if case .deduced = graded.verdict { return true }
        return false
    }

    private func verdictLine(_ graded: GradedMove) -> String {
        let clue = "the \(graded.move.rect.area)"
        switch graded.verdict {
        case .deduced(let technique):
            return "You worked out \(clue). \(TechniqueContent.name(for: technique)) gets the credit."
        case .shown:
            return "A hint laid \(clue) for you."
        case .leap:
            return "\(clue.capitalized) was right, and it goes further than the lessons reach. That one was a leap."
        }
    }

    private var controls: some View {
        HStack(spacing: Layout.s5) {
            Button {
                if step > 0 { step -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(QuietButtonStyle())
            .disabled(step == 0)
            .accessibilityLabel("Previous move")

            Spacer()

            Button {
                if step < graded.count { step += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(QuietButtonStyle())
            .disabled(step >= graded.count)
            .accessibilityLabel("Next move")
        }
        .padding(.horizontal, Layout.s5)
    }
}

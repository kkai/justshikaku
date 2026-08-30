//
//  SpotItView.swift
//  Shikaku
//
//  Spot It: ten real mid-solve positions where one technique is the move.
//  Lay the right mat and the next position slides in; a wrong mat is a
//  strike, and three strikes end the run. No clock — accuracy is the game.
//  Positions are mined from generated boards while you play, so every rep
//  has a full board's context and the solver's word that the technique
//  really applies.
//

import SwiftUI

struct SpotItView: View {
    let technique: Technique

    @Environment(MasteryTracker.self) private var mastery
    @Environment(\.dismiss) private var dismiss

    nonisolated static let runLength = 10
    private static let strikeLimit = 3

    @State private var positions: [LessonPositions.Position] = []
    @State private var mined = false
    @State private var index = 0
    @State private var cleared = 0
    @State private var strikes = 0
    @State private var game: ShikakuGame?
    @State private var feedback: Feedback?
    @State private var finished = false

    private enum Feedback { case hit(Technique), miss }

    var body: some View {
        ZStack {
            Theme.floor.ignoresSafeArea()
            if let game, !finished {
                VStack(spacing: Layout.s4) {
                    header
                    Spacer(minLength: 0)
                    RoomBoard(game: game)
                        .id(index)
                    Spacer(minLength: 0)
                    feedbackRail
                }
                .padding(.vertical, Layout.s4)
            } else if finished {
                summary
            } else {
                PuzzleLoadingView()
            }
        }
        .navigationTitle("Spot it")
        .navigationBarTitleDisplayMode(.inline)
        .swipeBackDisabled()
        .task { await mine() }
        .onChange(of: game?.board) { checkAnswer() }
    }

    private var header: some View {
        HStack {
            Text(TechniqueContent.name(for: technique))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            Text("\(cleared) of \(Self.runLength)")
                .font(Theme.numberFont(size: 15))
                .foregroundStyle(Theme.inkSoft)
            strikesView
        }
        .padding(.horizontal, Layout.s4)
    }

    /// Three small stones; a strike hatches one.
    private var strikesView: some View {
        HStack(spacing: 4) {
            ForEach(0..<Self.strikeLimit, id: \.self) { slot in
                Rectangle()
                    .fill(Theme.frame)
                    .overlay { if slot < strikes { Hatching(pitch: 3, lineWidth: 1) } }
                    .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
                    .frame(width: 12, height: 12)
            }
        }
        .accessibilityLabel("\(strikes) of \(Self.strikeLimit) strikes")
    }

    @ViewBuilder
    private var feedbackRail: some View {
        switch feedback {
        case .hit(let credited):
            AnnotationRail(marked: true) {
                Text("That's it. \(TechniqueContent.name(for: credited)) all the way.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
            }
        case .miss:
            AnnotationRail {
                Text("Not that one. The \(TechniqueContent.name(for: technique)) mat is still open.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
            }
        case nil:
            AnnotationRail {
                Text("Lay the mat that \(TechniqueContent.name(for: technique)) forces.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var summary: some View {
        VStack(spacing: Layout.s4) {
            Text(strikes >= Self.strikeLimit ? "Three strikes." : "Run finished.")
                .font(Theme.heading)
                .foregroundStyle(Theme.ink)
            Text("\(cleared) of \(Self.runLength) spotted.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
            Button("Done") {
                mastery.recordDrill(technique: technique)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Layout.s6)
        }
    }

    // MARK: - Run

    /// Mines in the background and streams positions in; the first position
    /// appears as soon as it exists.
    private func mine() async {
        guard !mined else { return }
        mined = true
        let technique = technique
        let seed = UInt64.random(in: .min ... .max)
        let found = await Task.detached(priority: .userInitiated) {
            LessonPositions.mine(technique: technique, count: Self.runLength,
                                 seed: seed)
        }.value
        positions = found
        if positions.isEmpty {
            // The lesson board is always a valid single rep.
            let lesson = TutorialPuzzles.lesson(for: technique)
            let answer = lesson.puzzle.solution.indices.first {
                !lesson.preplacedClues.contains($0)
            } ?? 0
            positions = [LessonPositions.Position(
                puzzle: lesson.puzzle,
                preplaced: lesson.preplaced.map {
                    Placement(clueIndex: $0.clueIndex, rect: $0.rect)
                },
                answerClue: answer)]
        }
        loadPosition()
    }

    private func loadPosition() {
        let position = positions[index % positions.count]
        game = ShikakuGame(puzzle: position.puzzle, size: .five,
                           difficulty: .gentle, board: position.startingBoard)
        feedback = nil
    }

    /// A new mat on the board is the player's answer.
    private func checkAnswer() {
        guard let game, !finished else { return }
        let position = positions[index % positions.count]
        let laid = Set(game.board.placed.map(\.clueIndex))
        let pre = Set(position.preplaced.map(\.clueIndex))
        guard let newClue = laid.subtracting(pre).first else { return }
        guard let placed = game.board.placed.first(where: { $0.clueIndex == newClue })
        else { return }

        if placed.rect == position.puzzle.solution[newClue] {
            // Correct rect — credit the technique the position teaches.
            feedback = .hit(technique)
            cleared += 1
            advance()
        } else {
            feedback = .miss
            strikes += 1
            game.undo()
            if strikes >= Self.strikeLimit { finished = true }
        }
    }

    private func advance() {
        if cleared >= Self.runLength {
            finished = true
            return
        }
        index += 1
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            loadPosition()
        }
    }
}

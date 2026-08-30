//
//  DrillView.swift
//  Shikaku
//
//  A drill: one technique's board, solved cold. No prompts, no staged
//  argument — the lesson's position, against your own best judgement, timed.
//  Finishing records the drill; laying the key mats without hints earns the
//  same unaided credit as a real game (the game carries the mastery tracker,
//  so `creditIfDeduced` runs exactly as it does in play).
//

import SwiftUI

struct DrillView: View {
    let technique: Technique

    @Environment(MasteryTracker.self) private var mastery
    @Environment(\.dismiss) private var dismiss

    @State private var game: ShikakuGame
    @State private var seconds = 0
    @State private var recorded = false

    init(technique: Technique) {
        self.technique = technique
        let lesson = TutorialPuzzles.lesson(for: technique)
        _game = State(initialValue: ShikakuGame(
            puzzle: lesson.puzzle, size: .five, difficulty: .gentle,
            board: lesson.startingBoard))
    }

    var body: some View {
        ZStack {
            Theme.floor.ignoresSafeArea()
            VStack(spacing: Layout.s4) {
                header
                Spacer(minLength: 0)
                RoomBoard(game: game)
                Spacer(minLength: 0)
                if game.didWin {
                    doneRail
                }
            }
            .padding(.vertical, Layout.s4)
        }
        .navigationTitle("Drill")
        .navigationBarTitleDisplayMode(.inline)
        .swipeBackDisabled()
        .task {
            game.mastery = mastery
            while !Task.isCancelled && !game.didWin {
                try? await Task.sleep(for: .seconds(1))
                seconds += 1
            }
        }
        .onChange(of: game.didWin) {
            guard game.didWin, !recorded else { return }
            recorded = true
            mastery.recordDrill(technique: technique)
        }
    }

    private var header: some View {
        HStack {
            Text(TechniqueContent.name(for: technique))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            Text(TimeFormatting.clock(seconds))
                .font(Theme.numberFont(size: 17))
                .foregroundStyle(Theme.inkSoft)
                .monospacedDigit()
        }
        .padding(.horizontal, Layout.s4)
    }

    private var doneRail: some View {
        AnnotationRail {
            HStack(alignment: .firstTextBaseline, spacing: Layout.s3) {
                Text("Drilled in \(TimeFormatting.clock(seconds)) without a hint.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.heri)
            }
        }
    }
}

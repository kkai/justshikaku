//
//  LessonView.swift
//  Shikaku
//
//  A technique lesson: see the rule, watch the argument drawn on a real
//  position, then make the move yourself. The player always lays the mat —
//  the lesson never places it for them; watching is not learning.
//

import SwiftUI

struct LessonView: View {
    let technique: Technique

    @Environment(MasteryTracker.self) private var mastery
    @Environment(\.dismiss) private var dismiss

    @State private var game: ShikakuGame
    @State private var phase = Phase.intro
    @State private var argumentStep: SolverStep?
    @State private var expectedPlacement: Placement?

    private enum Phase { case intro, argument, play, done }

    init(technique: Technique) {
        self.technique = technique
        let board = TutorialPuzzles.lesson(for: technique)
        _game = State(initialValue: ShikakuGame(
            puzzle: board.puzzle, size: .five, difficulty: .gentle,
            board: board.startingBoard))
    }

    var body: some View {
        ZStack {
            Theme.floor.ignoresSafeArea()
            VStack(spacing: Layout.s4) {
                Text(TechniqueContent.name(for: technique))
                    .font(Theme.heading)
                    .foregroundStyle(Theme.ink)
                RoomBoard(game: game)
                    .allowsHitTesting(phase == .play)
                prompt
                Spacer(minLength: Layout.s2)
                controls
            }
            .padding(.vertical, Layout.s4)
        }
        .navigationTitle("Lesson")
        .navigationBarTitleDisplayMode(.inline)
        .swipeBackDisabled()
        .onAppear(perform: prepare)
        .onChange(of: game.board) { checkProgress() }
    }

    private var prompt: some View {
        // Marked while the argument is being drawn: the vermilion bar is the
        // app saying "this is the teaching part", and it is the only place
        // shu appears on a lesson screen.
        AnnotationRail(marked: phase == .argument) {
            Text(promptText)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var promptText: String {
        switch phase {
        case .intro:
            TechniqueContent.rule(for: technique)
        case .argument:
            argumentStep.map { TechniqueContent.detail(for: $0, puzzle: game.puzzle) }
                ?? TechniqueContent.rule(for: technique)
        case .play:
            "Your turn. Lay the mat the argument points to."
        case .done:
            "That's the move. You'll spot it on real boards now."
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .intro:
            Button("Show me") { showArgument() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Layout.s6)
        case .argument:
            Button("Your turn") {
                phase = .play
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Layout.s6)
        case .play:
            Button("Show the argument again") { showArgument() }
                .buttonStyle(QuietButtonStyle())
        case .done:
            Button("Done") {
                mastery.recordDrill(technique: technique)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Layout.s6)
        }
    }

    /// Walks the solver from the lesson position: the target technique's
    /// step becomes the drawn argument; the first placement that follows is
    /// what the player must lay.
    private func prepare() {
        guard argumentStep == nil else { return }
        var state = SolverState(puzzle: game.puzzle, board: game.board)
        var guardCount = 0
        while guardCount < 100,
              let step = LogicalSolver.nextStep(puzzle: game.puzzle, state: state) {
            guardCount += 1
            if argumentStep == nil && step.technique == technique {
                argumentStep = step
            }
            if let placement = step.placement, argumentStep != nil {
                expectedPlacement = placement
                return
            }
            state.apply(step: step)
        }
    }

    private func showArgument() {
        guard let step = argumentStep else { return }
        game.activeHint = Hint(
            level: .highlight, step: step,
            text: TechniqueContent.detail(for: step, puzzle: game.puzzle),
            focusCells: step.focusCells(in: game.puzzle))
        if phase == .intro { phase = .argument }
    }

    private func checkProgress() {
        guard phase == .play, let expected = expectedPlacement else { return }
        if game.board.placed.contains(PlacedRect(rect: expected.rect,
                                                 clueIndex: expected.clueIndex)) {
            phase = .done
        }
    }
}

// MARK: - Rules tutorial

/// Three moves on a 3×3: tap a 1, drag a 2, finish the 6. The whole rule
/// set, felt rather than read.
struct RulesTutorialView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var game = ShikakuGame(
        puzzle: TutorialPuzzles.rules.puzzle, size: .five, difficulty: .gentle,
        board: TutorialPuzzles.rules.startingBoard)

    var body: some View {
        ZStack {
            Theme.floor.ignoresSafeArea()
            VStack(spacing: Layout.s4) {
                Text("The rules")
                    .font(Theme.heading)
                    .foregroundStyle(Theme.ink)
                RoomBoard(game: game)
                AnnotationRail {
                    Text(promptText)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Layout.s2)
                if game.didWin {
                    Button("I'm ready") { dismiss() }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, Layout.s6)
                }
            }
            .padding(.vertical, Layout.s4)
        }
        .navigationTitle("Learn")
        .navigationBarTitleDisplayMode(.inline)
        .swipeBackDisabled()
    }

    private var promptText: String {
        let placed = Set(game.board.placed.map(\.clueIndex))
        if game.didWin {
            return "That's Shikaku: every number housed in a rectangle of exactly its size, no gaps, no overlaps."
        }
        if !placed.contains(0) {
            return "Every number gets a rectangle with exactly that many cells. Start small: tap the 1, a room of one."
        }
        if !placed.contains(1) {
            return "Now drag from the 2 across two cells. Any two will do here, as long as the 2 is inside and nothing else is."
        }
        return "One number left. Drag the 6 over everything that remains."
    }
}

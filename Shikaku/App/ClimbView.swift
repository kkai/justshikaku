//
//  ClimbView.swift
//  Shikaku
//
//  The Climb: room after room, each stage a step up the technique ladder.
//  A mat that cannot be part of the finished room is a strike; three
//  strikes end the run. There is no clock anywhere — the run is about
//  staying right, not being fast. The score is rooms finished.
//

import SwiftUI

/// The ladder. After the last rung it stays on severe with fresh seeds.
nonisolated enum ClimbLadder {
    static let stages: [(size: BoardSize, tier: Difficulty)] = [
        (.five, .gentle), (.five, .steady), (.five, .sharp),
        (.seven, .steady), (.seven, .deep), (.seven, .severe),
    ]

    static func stage(_ index: Int) -> (size: BoardSize, tier: Difficulty) {
        index < stages.count ? stages[index] : stages[stages.count - 1]
    }
}

struct ClimbView: View {
    @Environment(MasteryTracker.self) private var mastery
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss

    private static let strikeLimit = 3

    @State private var stage = 0
    @State private var strikes = 0
    @State private var game: ShikakuGame?
    @State private var struckPlacements: Set<PlacedRect> = []
    @State private var finished = false
    @State private var generating = false

    var body: some View {
        ZStack {
            Theme.floor.ignoresSafeArea()
            if finished {
                summary
            } else if let game {
                VStack(spacing: Layout.s4) {
                    header
                    Spacer(minLength: 0)
                    RoomBoard(game: game)
                        .id(stage)
                    Spacer(minLength: 0)
                    footer
                }
                .padding(.vertical, Layout.s4)
            } else {
                PuzzleLoadingView()
            }
        }
        .navigationTitle("The Climb")
        .modeGuide(.climb)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBackDisabled()
        .task { await loadStage() }
        .onChange(of: game?.board) { judgeNewMats() }
        .onChange(of: game?.didWin) {
            guard game?.didWin == true else { return }
            stage += 1
            Task {
                try? await Task.sleep(for: .milliseconds(1200))
                await loadStage()
            }
        }
    }

    private var header: some View {
        HStack {
            let plan = ClimbLadder.stage(stage)
            Text("Room \(stage + 1) · \(plan.size.label)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
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
        .padding(.horizontal, Layout.s4)
    }

    private var footer: some View {
        HStack {
            Button {
                game?.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(QuietButtonStyle())
            .disabled(game?.canUndo != true)
            .accessibilityLabel("Undo")
            Spacer()
        }
        .padding(.horizontal, Layout.s5)
    }

    private var summary: some View {
        VStack(spacing: Layout.s4) {
            Text("The climb ends.")
                .font(Theme.heading)
                .foregroundStyle(Theme.ink)
            Text(stage == 1 ? "1 room finished." : "\(stage) rooms finished.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
            if stage > progress.climbBest {
                Text("Your best climb yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.heri)
            }
            Button("Done") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Layout.s6)
        }
        .onAppear { progress.recordClimb(rooms: stage) }
    }

    private func loadStage() async {
        guard !generating, !finished else { return }
        generating = true
        defer { generating = false }
        game = nil
        struckPlacements = []
        let plan = ClimbLadder.stage(stage)
        let seed = UInt64.random(in: .min ... .max)
        let result = await Task.detached(priority: .userInitiated) {
            ShikakuGenerator.generate(size: plan.size, tier: plan.tier, seed: seed)
        }.value
        let fresh = ShikakuGame(puzzle: result.puzzle, size: plan.size,
                                difficulty: plan.tier)
        fresh.mastery = mastery
        game = fresh
    }

    /// A newly committed mat that cannot be part of the finished room is a
    /// strike. Each wrong placement strikes once — undoing and redoing the
    /// same mistake does not stack.
    private func judgeNewMats() {
        guard let game, !finished else { return }
        for placed in game.wrongPlacements where !struckPlacements.contains(placed) {
            struckPlacements.insert(placed)
            strikes += 1
            Haptics.reject()
            if strikes >= Self.strikeLimit {
                finished = true
                return
            }
        }
    }
}

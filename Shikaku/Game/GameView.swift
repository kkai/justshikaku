//
//  GameView.swift
//  Shikaku
//
//  The play screen: chrome around BoardView, the save-as-you-work policy,
//  and the win moment. Saving happens on board change + scene backgrounding
//  + disappear — never phase-change-only, which silently loses a game that
//  was started and never paused (a sibling shipped that twice).
//

import SwiftUI

struct GameView: View {
    let game: ShikakuGame

    @Environment(ProgressStore.self) private var progress
    @Environment(PuzzleCache.self) private var cache
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    @State private var wasRecord = false

    var body: some View {
        ZStack {
            Theme.floor.ignoresSafeArea()
            // Top-aligned: the board belongs under the player's thumbline,
            // not floating in a centred block with dead straw above it.
            VStack(spacing: Layout.s4) {
                header
                BoardView(game: game)
                    .padding(.horizontal, Layout.s2)
                HintBanner(game: game)
                    .animation(Motion.chrome, value: game.activeHint)
                Spacer(minLength: 0)
                footer
            }
            .padding(.top, Layout.s3)
            if game.didWin {
                WinOverlay(game: game, wasRecord: wasRecord) {
                    dismiss()
                }
                .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(game.didWin)
        .task(id: game.didWin) {
            guard game.didWin else { return }
            progress.clearSavedGame()
            wasRecord = progress.recordSolve(
                size: game.size, difficulty: game.difficulty,
                seconds: game.elapsedSeconds, hintsUsed: game.hintsUsed)
            cache.warm(size: game.size, tier: game.difficulty)
        }
        .task {
            // One warm pass for "next puzzle" while the player thinks.
            cache.warm(size: game.size, tier: game.difficulty)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                game.tickSecond()
            }
        }
        .onChange(of: game.board) {
            guard !game.didWin else { return }
            progress.save(game.snapshot)
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active && !game.didWin {
                progress.save(game.snapshot)
            }
        }
        .onDisappear {
            if !game.didWin {
                progress.save(game.snapshot)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("\(game.size.label) · \(game.difficulty.label)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            Text(TimeFormatting.clock(game.elapsedSeconds))
                .font(Theme.numberFont(size: 17))
                .foregroundStyle(Theme.inkSoft)
                .monospacedDigit()
                .accessibilityLabel("Elapsed \(TimeFormatting.spoken(game.elapsedSeconds))")
        }
        .padding(.horizontal, Layout.s4)
    }

    private var footer: some View {
        HStack(spacing: Layout.s5) {
            Button {
                game.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(QuietButtonStyle())
            .disabled(!game.canUndo)
            .accessibilityLabel("Undo")

            Spacer()

            // The hint ladder arrives with the Teaching layer; the button is
            // laid out now so the board height is final.
            HintButton(game: game)
        }
        .padding(.horizontal, Layout.s5)
        .padding(.bottom, Layout.s3)
    }
}

// MARK: - Win

/// The room finishes: a light sweep crosses the floor and the kaki hanko
/// stamp lands with the time. The only celebration in the app, and the only
/// time kaki appears outside an error.
private struct WinOverlay: View {
    let game: ShikakuGame
    let wasRecord: Bool
    let done: () -> Void

    @State private var stamped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Layout.s4) {
            Spacer()
            stamp
            Text(TimeFormatting.clock(game.elapsedSeconds))
                .font(Theme.numberFont(size: 34))
                .foregroundStyle(Theme.ink)
            if wasRecord {
                Text("Your best yet on this size.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Button("Done") { done() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Layout.s6)
                .padding(.bottom, Layout.s6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.floor.opacity(0.94).ignoresSafeArea())
        .onAppear {
            withAnimation(reduceMotion ? Motion.chrome : Motion.winSweep) { stamped = true }
        }
        .accessibilityAddTraits(.isModal)
    }

    private var stamp: some View {
        Text("済")
            .font(.system(size: 64, weight: .bold))
            .foregroundStyle(Theme.surface)
            .frame(width: 110, height: 110)
            .background(Theme.kaki, in: RoundedRectangle(cornerRadius: 10))
            .rotationEffect(.degrees(stamped ? -6 : -20))
            .scaleEffect(stamped ? 1.0 : 1.6)
            .opacity(stamped ? 1 : 0)
            .accessibilityLabel("Solved")
    }
}

// MARK: - Formatting

nonisolated enum TimeFormatting {
    static func clock(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    static func spoken(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return m > 0 ? "\(m) minutes \(s) seconds" : "\(s) seconds"
    }
}

extension Difficulty {
    var label: String {
        switch self {
        case .gentle: "Gentle"
        case .steady: "Steady"
        case .sharp: "Sharp"
        case .deep: "Deep"
        case .severe: "Severe"
        }
    }
}

extension BoardSize {
    var label: String { "\(rawValue)×\(rawValue)" }
}

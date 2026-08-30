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
            // The room sits in the middle of the screen with the controls
            // docked to the bottom edge. It used to be top-aligned against a
            // 64pt cell cap, which left the lower 40% of every screen — and
            // every App Store screenshot — empty.
            VStack(spacing: Layout.s4) {
                header
                Spacer(minLength: 0)
                // No horizontal padding: the wood band runs to the screen
                // edges, so the room is the full width of the phone.
                RoomBoard(game: game)
                Spacer(minLength: 0)
                // Docked directly above the controls rather than floating
                // under the board: the rail then appears in the same place
                // every time instead of shunting the room up the screen.
                HintBanner(game: game)
                    .animation(Motion.chrome, value: game.activeHint)
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
        .swipeBackDisabled()
        .navigationBarBackButtonHidden(game.didWin)
        .task(id: game.didWin) {
            guard game.didWin else { return }
            if let day = game.dailyDay {
                // The daily records into the streak, not the best-time table,
                // and never owned the save slot.
                progress.recordDailyCompleted(day: day, seconds: game.elapsedSeconds)
            } else {
                progress.clearSavedGame()
                wasRecord = progress.recordSolve(
                    size: game.size, difficulty: game.difficulty,
                    seconds: game.elapsedSeconds, hintsUsed: game.hintsUsed)
                cache.warm(size: game.size, tier: game.difficulty)
            }
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
            guard !game.didWin, game.dailyDay == nil else { return }
            progress.save(game.snapshot)
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active && !game.didWin && game.dailyDay == nil {
                progress.save(game.snapshot)
            }
        }
        .onDisappear {
            if !game.didWin && game.dailyDay == nil {
                progress.save(game.snapshot)
            }
        }
    }

    private var header: some View {
        HStack {
            Text(game.dailyDay != nil
                 ? "Today's room · \(game.size.label)"
                 : "\(game.size.label) · \(game.difficulty.label)")
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

/// The room finishes: a light sweep crosses the floor and the vermilion hanko
/// stamp lands with the time. The only celebration in the app, and the only
/// time shu appears at full strength.
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
            Text("The room is finished.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
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
            .foregroundStyle(Theme.ink)
            .frame(width: 110, height: 110)
            .background(Theme.shu, in: Rectangle())
            .overlay(Rectangle().strokeBorder(.black.opacity(0.3), lineWidth: 1))
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

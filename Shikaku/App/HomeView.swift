//
//  HomeView.swift
//  Shikaku
//
//  The title screen: the room itself, the curriculum, and one way in.
//
//  What this screen has to do in three seconds is show what the game looks
//  like, show that it teaches, and get the player onto a board. The previous
//  version did none of those — it was a configuration form (two chip rows, a
//  play bar, a Learn card) on which the board never appeared, with roughly
//  60% of the screen empty below it.
//
//  The structural move that unlocked the rest: size and difficulty left the
//  front page for a sheet (NewRoomSheet), and the last-played choice is
//  restored, so most sessions never see a picker at all.
//

import SwiftUI

struct HomeView: View {
    @Binding var path: [Route]

    @Environment(ProgressStore.self) private var progress
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PuzzleCache.self) private var cache
    @Environment(MasteryTracker.self) private var mastery

    @State private var size: BoardSize = .five
    @State private var difficulty: Difficulty = .gentle
    @State private var showingNewRoom = false

    var body: some View {
        ZStack {
            Theme.floor.ignoresSafeArea()
            VStack(spacing: 0) {
                lintel
                // One flexible gap, below the room rather than around it: the
                // room hangs off the lintel and the controls sit on the floor,
                // instead of a symmetric float with dead space top and bottom.
                Spacer().frame(height: Layout.s6)
                liveRoom
                roomCaption
                Spacer(minLength: Layout.s5)
                VStack(spacing: Layout.s5) {
                    Button { path.append(.learn) } label: {
                        TechniquePath(mastery: mastery)
                    }
                    .buttonStyle(.plain)
                    playButton
                }
                .padding(.horizontal, Layout.s5)
                .padding(.bottom, Layout.s4)
            }
        }
        .toolbar { toolbarItems }
        .sheet(isPresented: $showingNewRoom) {
            NewRoomSheet(size: $size, difficulty: $difficulty, onStart: start)
        }
        .onAppear(perform: restoreLastPlayed)
    }

    // MARK: - The lintel

    /// A band of timber across the head of the screen with the wordmark set
    /// into it — the same wood the board is framed in, so the app reads as
    /// one built object rather than a page with a title on it.
    private var lintel: some View {
        HStack(spacing: Layout.s3) {
            ShikakuMark(side: 32)
            Text("Just Shikaku")
                .font(Theme.title)
                .foregroundStyle(Theme.ink)
                .shadow(color: .black.opacity(0.55), radius: 0, y: 1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Layout.s5)
        .padding(.vertical, Layout.s4)
        .frame(maxWidth: .infinity)
        .background(Theme.frame)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.black.opacity(0.45)).frame(height: 1)
        }
    }

    // MARK: - The live room

    /// The board, on the front page, in the full material treatment.
    ///
    /// Every competitor's home screen is a menu. This one is the game: if a
    /// save exists the miniature *is* that board and tapping it continues; on
    /// a first run it shows a laid demo room and points at the rules instead.
    private var liveRoom: some View {
        Button {
            if progress.savedGame != nil {
                path.append(.resume)
            } else {
                path.append(.learn)
            }
        } label: {
            RoomBoard(game: roomGame)
                .allowsHitTesting(false)
                .frame(maxWidth: 340)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(progress.savedGame != nil
                            ? "Continue your room, \(savedLabel)"
                            : "Learn the rules")
    }

    private var roomCaption: some View {
        Text(progress.savedGame != nil ? savedLabel : "Learn the rules first.")
            .font(progress.savedGame != nil ? Theme.numberFont(size: 13) : .subheadline)
            .foregroundStyle(Theme.inkSoft)
            .padding(.top, Layout.s3)
    }

    /// The saved board when there is one, otherwise a laid demo room. Held in
    /// a computed property rather than `@State` so a save made on the play
    /// screen is reflected the moment the player comes back.
    private var roomGame: ShikakuGame {
        if let saved = progress.savedGame {
            return ShikakuGame(
                puzzle: saved.puzzle,
                size: BoardSize(rawValue: saved.sizeRaw) ?? .five,
                difficulty: Difficulty(rawValue: saved.difficultyRaw) ?? .gentle,
                board: saved.board)
        }
        // A real lesson position: a 7×7 with two mats already laid, so a
        // first run still sees a room with something in it.
        let demo = TutorialPuzzles.lesson(for: .corridorCount)
        return ShikakuGame(puzzle: demo.puzzle, size: .seven, difficulty: .gentle,
                           board: demo.startingBoard)
    }

    private var savedLabel: String {
        guard let saved = progress.savedGame else { return "" }
        let size = BoardSize(rawValue: saved.sizeRaw)?.label ?? ""
        let tier = Difficulty(rawValue: saved.difficultyRaw)?.label ?? ""
        return "\(size) · \(tier) · \(TimeFormatting.clock(saved.elapsedSeconds))"
    }

    // MARK: - Getting in

    private var playButton: some View {
        Button("Lay out a room") { showingNewRoom = true }
            .buttonStyle(PrimaryButtonStyle())
    }

    private func start() {
        progress.recordLastPlayed(size: size, difficulty: difficulty)
        path.append(.play(size: size, difficulty: difficulty))
    }

    /// Restores the last choice and warms a puzzle for it, so the common path
    /// — open the app, tap through the sheet — does not meet a loading
    /// screen. Warming is skipped for a size the player cannot open.
    private func restoreLastPlayed() {
        guard let choice = progress.lastPlayed else { return }
        size = choice.size
        difficulty = choice.difficulty
        guard FeatureGate.isBoardSizeAvailable(choice.size, unlocked: entitlements.isUnlocked)
        else { return }
        cache.warm(size: choice.size, tier: choice.difficulty)
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: Layout.s2) {
                Button { path.append(.stats) } label: {
                    Image(systemName: "chart.bar")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Statistics")
                Button { path.append(.settings) } label: {
                    Image(systemName: "gearshape")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Settings")
            }
            .foregroundStyle(Theme.inkSoft)
        }
    }
}

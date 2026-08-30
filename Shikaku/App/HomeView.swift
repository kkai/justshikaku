//
//  HomeView.swift
//  Shikaku
//
//  The start screen: wordmark with the drag-diagonal, the daily, Continue,
//  one way into a new room, and the seal path. A column of real buttons —
//  the previous version led with a large non-interactive board, which looked
//  playable and wasn't; everything here does what it looks like it does.
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
            // The board's lattice dots as a whisper on the floor: Home stays
            // in the game's world without pretending to be a board.
            FloorDots()
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.s5) {
                    Wordmark()
                    DailyCard(path: $path)
                    if progress.savedGame != nil {
                        continueCard
                    }
                    playButton
                    sealPath
                }
                .padding(Layout.s5)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar { toolbarItems }
        .sheet(isPresented: $showingNewRoom) {
            NewRoomSheet(size: $size, difficulty: $difficulty, onStart: start)
        }
        .onAppear(perform: restoreLastPlayed)
    }

    // MARK: - Continue

    private var continueCard: some View {
        Button {
            Haptics.previewTick()
            path.append(.resume)
        } label: {
            HStack(spacing: Layout.s4) {
                if let saved = progress.savedGame {
                    BoardThumbnail(puzzle: saved.puzzle, board: saved.board)
                        .frame(width: 56, height: 56)
                }
                VStack(alignment: .leading, spacing: Layout.s1) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(savedLabel)
                        .font(Theme.numberFont(size: 13))
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

    private var savedLabel: String {
        guard let saved = progress.savedGame else { return "" }
        let size = BoardSize(rawValue: saved.sizeRaw)?.label ?? ""
        let tier = Difficulty(rawValue: saved.difficultyRaw)?.label ?? ""
        return "\(size) · \(tier) · \(TimeFormatting.clock(saved.elapsedSeconds))"
    }

    // MARK: - New room

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

    // MARK: - The seal path

    /// Each seal is a real button into its own lesson — the row is the
    /// curriculum's front door, not a decoration. A gated technique routes to
    /// the Learn menu instead, whose locked rows present the paywall (the
    /// family rule: gates are tappable, never dead).
    private var sealPath: some View {
        TechniquePath(mastery: mastery) { technique in
            if FeatureGate.isLessonAvailable(technique, unlocked: entitlements.isUnlocked) {
                path.append(.lesson(technique))
            } else {
                path.append(.learn)
            }
        }
        .padding(.top, Layout.s2)
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

// MARK: - Shared home vocabulary

extension View {
    /// The home card: a step up from the floor, square, hairline-edged. The
    /// same material logic as the mats and seals — Kakuro-like in
    /// composition, never in corner radius.
    func homeCard() -> some View {
        background(Theme.surface)
            .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
    }
}

/// A small non-interactive render of a board — the Continue card's preview
/// and the daily's done-state. Deliberately chrome-free: lattice and mats
/// only, no clues at this size.
struct BoardThumbnail: View {
    let puzzle: Puzzle
    let board: BoardState

    var body: some View {
        GeometryReader { proxy in
            let geo = BoardGeometry(size: puzzle.size, container: proxy.size)
            ZStack(alignment: .topLeading) {
                ForEach(board.placed, id: \.self) { placed in
                    let f: CGRect = geo.rect(for: placed.rect)
                    Rectangle()
                        .fill(Theme.mat)
                        .overlay(Rectangle().strokeBorder(Theme.heri, lineWidth: 0.5))
                        .frame(width: f.width, height: f.height)
                        .position(x: f.midX, y: f.midY)
                        .padding(0.5)
                }
            }
            .background(Theme.floor)
            .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .aspectRatio(1, contentMode: .fit)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The board's intersection dots, tiled across the floor at low contrast.
private struct FloorDots: View {
    var body: some View {
        Canvas { context, size in
            let pitch: CGFloat = 44
            let r: CGFloat = 1.2
            var y: CGFloat = pitch / 2
            while y < size.height {
                var x: CGFloat = pitch / 2
                while x < size.width {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                        with: .color(.white.opacity(0.03)))
                    x += pitch
                }
                y += pitch
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

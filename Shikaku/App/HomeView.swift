//
//  HomeView.swift
//  Shikaku
//
//  The room list: continue card, size and difficulty pickers, play.
//  Paywalled sizes stay tappable and present the paywall — never .disabled
//  (the family rule: a locked row that cannot be tapped cannot be bought).
//

import SwiftUI

struct HomeView: View {
    @Binding var path: [Route]

    @Environment(ProgressStore.self) private var progress
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall

    @State private var size: BoardSize = .five
    @State private var difficulty: Difficulty = .gentle

    var body: some View {
        ZStack {
            Theme.floor.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.s5) {
                    wordmark
                    if progress.savedGame != nil {
                        continueCard
                    }
                    sizePicker
                    difficultyPicker
                    playButton
                    learnRow
                }
                .padding(Layout.s5)
            }
        }
        .toolbar {
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

    private var wordmark: some View {
        VStack(alignment: .leading, spacing: Layout.s1) {
            Text("Just Shikaku")
                .font(Theme.title)
                .foregroundStyle(Theme.ink)
            Text("Divide the room into rectangles.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private var continueCard: some View {
        Button {
            path.append(.resume)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Layout.s1) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    if let saved = progress.savedGame {
                        Text(savedLabel(saved))
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(Layout.s4)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Layout.cardRadius))
        }
        .buttonStyle(.plain)
    }

    private func savedLabel(_ saved: GameSnapshot) -> String {
        let size = BoardSize(rawValue: saved.sizeRaw)?.label ?? ""
        let tier = Difficulty(rawValue: saved.difficultyRaw)?.label ?? ""
        return "\(size) · \(tier) · \(TimeFormatting.clock(saved.elapsedSeconds))"
    }

    private var sizePicker: some View {
        VStack(alignment: .leading, spacing: Layout.s2) {
            Text("Room size")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
            HStack(spacing: Layout.s2) {
                ForEach(BoardSize.allCases) { candidate in
                    sizeChip(candidate)
                }
            }
        }
    }

    @ViewBuilder
    private func sizeChip(_ candidate: BoardSize) -> some View {
        let available = FeatureGate.isBoardSizeAvailable(candidate, unlocked: entitlements.isUnlocked)
        let selected = size == candidate
        Button {
            if available {
                size = candidate
            } else {
                paywall.present(.largerBoards)
            }
        } label: {
            HStack(spacing: 3) {
                Text(candidate.label)
                    .font(Theme.numberFont(size: 15))
                if !available {
                    Image(systemName: "lock")
                        .font(.caption2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Layout.s2)
            .background(
                selected ? AnyShapeStyle(Theme.ink) : AnyShapeStyle(Theme.surface),
                in: RoundedRectangle(cornerRadius: Layout.controlRadius))
            .foregroundStyle(selected ? Theme.surface : Theme.ink)
        }
        .accessibilityLabel("\(candidate.label)\(available ? "" : ", locked")")
    }

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: Layout.s2) {
            Text("Difficulty")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
            // One control vocabulary for the whole screen: the same ink-fill
            // chips as the size row, not a stock segmented control (system
            // gray chrome reads as someone else's app on this floor).
            // Difficulty is never gated: a free player can play severe.
            HStack(spacing: Layout.s1) {
                ForEach(Difficulty.allCases) { tier in
                    difficultyChip(tier)
                }
            }
        }
    }

    @ViewBuilder
    private func difficultyChip(_ tier: Difficulty) -> some View {
        let selected = difficulty == tier
        Button {
            difficulty = tier
        } label: {
            Text(tier.label)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Layout.s2)
                .background(
                    selected ? AnyShapeStyle(Theme.ink) : AnyShapeStyle(Theme.surface),
                    in: RoundedRectangle(cornerRadius: Layout.controlRadius))
                .foregroundStyle(selected ? Theme.surface : Theme.ink)
        }
        .accessibilityLabel("\(tier.label)\(selected ? ", selected" : "")")
    }

    private var playButton: some View {
        Button("Lay out a room") {
            path.append(.play(size: size, difficulty: difficulty))
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var learnRow: some View {
        Button {
            path.append(.learn)
        } label: {
            HStack {
                Image(systemName: "book")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Learn")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("The rules, then the seven ways to see a rectangle.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(Layout.s4)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Layout.cardRadius))
        }
        .buttonStyle(.plain)
    }
}

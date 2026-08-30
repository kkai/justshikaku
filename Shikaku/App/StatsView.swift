//
//  StatsView.swift
//  Shikaku
//
//  Best times are free; solve counts, the hints-taken trend, and the mastery
//  path come with the full game. The locked section stays tappable and
//  presents the paywall — never .disabled.
//

import SwiftUI

struct StatsView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(MasteryTracker.self) private var mastery

    var body: some View {
        List {
            dailySection
            bestTimesSection
            if FeatureGate.isFullStatsAvailable(unlocked: entitlements.isUnlocked) {
                solvesSection
                hintTrendSection
                masterySection
            } else {
                lockedSection
            }
        }
        .navigationTitle("Statistics")
        .scrollContentBackground(.hidden)
        .background(Theme.floor)
    }

    /// The streak belongs to the free daily and stays visible regardless of
    /// the unlock — per-panel gating, never a locked whole screen.
    private var dailySection: some View {
        Section("Today's room") {
            LabeledContent("Streak",
                           value: "\(progress.displayStreak(today: DayKey(date: .now)))")
            LabeledContent("Best streak", value: "\(progress.daily.bestStreak)")
            LabeledContent("Rooms finished", value: "\(progress.daily.completedTimes.count)")
        }
    }

    private var bestTimesSection: some View {
        Section("Best times") {
            ForEach(BoardSize.allCases) { size in
                bestTimesRow(size: size)
            }
        }
    }

    private func bestTimesRow(size: BoardSize) -> some View {
        HStack {
            Text(size.label)
                .font(Theme.numberFont(size: 15))
                .foregroundStyle(Theme.ink)
                .frame(width: 64, alignment: .leading)
            Spacer()
            ForEach(Difficulty.allCases) { tier in
                VStack(spacing: 2) {
                    Text(tier.label.prefix(1))
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                    Text(bestLabel(size: size, tier: tier))
                        .font(Theme.numberFont(size: 12))
                        .foregroundStyle(Theme.ink)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func bestLabel(size: BoardSize, tier: Difficulty) -> String {
        guard let best = progress.bestTime(size: size, difficulty: tier) else { return "–" }
        return TimeFormatting.clock(best)
    }

    private var solvesSection: some View {
        Section("Solved rooms") {
            LabeledContent("Total", value: "\(progress.stats.totalSolves)")
            ForEach(BoardSize.allCases) { size in
                let count = Difficulty.allCases.reduce(0) {
                    $0 + (progress.stats.solvesBySizeAndDifficulty[
                        ProgressStore.SolveKey(size: size, difficulty: $1)] ?? 0)
                }
                if count > 0 {
                    LabeledContent(size.label, value: "\(count)")
                }
            }
        }
    }

    /// The hints-taken trend — the number that proves the app works: as the
    /// techniques land, harder tiers should need fewer hints, not more.
    private var hintTrendSection: some View {
        Section("Hints taken, by difficulty") {
            ForEach(Difficulty.allCases) { tier in
                LabeledContent(tier.label,
                               value: "\(progress.stats.hintsByDifficulty[tier.rawValue] ?? 0)")
            }
        }
    }

    /// The seal path in detail: the same stones as Home, with each stage
    /// named and a finish line ("3 of 5 unaided") instead of a bare count.
    private var masterySection: some View {
        Section {
            TechniquePath(mastery: mastery)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, Layout.s2)
            ForEach(Technique.allCases) { technique in
                masteryRow(technique)
            }
        } header: {
            Text("Techniques")
        }
    }

    private func masteryRow(_ technique: Technique) -> some View {
        let record = progress.mastery.perTechnique[technique.rawValue]
        let stage = mastery.stage(for: technique)
        return LabeledContent {
            Text(stageLabel(stage, unaided: record?.unaided ?? 0))
                .font(Theme.numberFont(size: 13))
        } label: {
            Text(TechniqueContent.name(for: technique))
                .foregroundStyle(stage == .unseen ? Theme.inkSoft : Theme.ink)
        }
    }

    private func stageLabel(_ stage: MasteryTracker.Stage, unaided: Int) -> String {
        switch stage {
        case .unseen: "not yet met"
        case .seen: "introduced"
        case .practicing: "\(min(unaided, MasteryTracker.learnedThreshold)) of \(MasteryTracker.learnedThreshold) unaided"
        case .learned: "learned"
        }
    }

    private var lockedSection: some View {
        Section {
            Button {
                paywall.present(.fullStats)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Solve counts, hint trend, mastery path")
                            .foregroundStyle(Theme.ink)
                        Text("Comes with the full game. Your progress is already being tracked, so nothing is lost.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "lock")
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }
}

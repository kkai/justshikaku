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

    var body: some View {
        List {
            bestTimesSection
            if FeatureGate.isFullStatsAvailable(unlocked: entitlements.isUnlocked) {
                solvesSection
                masterySection
            } else {
                lockedSection
            }
        }
        .navigationTitle("Statistics")
        .scrollContentBackground(.hidden)
        .background(Theme.floor)
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
            LabeledContent("Hints taken", value: "\(progress.stats.totalHintsUsed)")
        }
    }

    private var masterySection: some View {
        Section("Techniques") {
            ForEach(Technique.allCases) { technique in
                let record = progress.mastery.perTechnique[technique.rawValue]
                LabeledContent(TechniqueContent.name(for: technique),
                               value: "\(record?.unaided ?? 0) unaided")
            }
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

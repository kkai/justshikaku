//
//  LearnMenuView.swift
//  Shikaku
//
//  The curriculum: the rules first, then the seven techniques in teaching
//  order. Paywalled rows stay tappable and present the paywall; nothing
//  gated is ever .disabled (the family rule — a row you can't tap can't be
//  bought).
//

import SwiftUI

struct LearnMenuView: View {
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(MasteryTracker.self) private var mastery

    var body: some View {
        List {
            Section {
                NavigationLink {
                    RulesTutorialView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("The rules")
                            .foregroundStyle(Theme.ink)
                        Text("Three moves on a tiny board")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            Section("Ways to play") {
                ForEach(ModeGuide.listed) { mode in
                    NavigationLink {
                        ModeGuideView(mode: mode)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ModeGuide.title(mode))
                                .foregroundStyle(Theme.ink)
                            Text(ModeGuide.oneLine(mode))
                                .font(.subheadline)
                                .foregroundStyle(Theme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            Section("Techniques") {
                ForEach(Technique.allCases) { technique in
                    row(for: technique)
                }
            }
            Section {
                practiceRow
            } footer: {
                Text("Practice runs a technique's board again, against your own best judgement.")
            }
        }
        .navigationTitle("Learn")
        .scrollContentBackground(.hidden)
        .background(Theme.floor)
    }

    @ViewBuilder
    private func row(for technique: Technique) -> some View {
        let available = FeatureGate.isLessonAvailable(technique, unlocked: entitlements.isUnlocked)
        if available {
            NavigationLink {
                LessonView(technique: technique)
            } label: {
                rowLabel(for: technique, locked: false)
            }
        } else {
            Button {
                paywall.present(.lessons)
            } label: {
                rowLabel(for: technique, locked: true)
            }
        }
    }

    private func rowLabel(for technique: Technique, locked: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(TechniqueContent.name(for: technique))
                    .foregroundStyle(Theme.ink)
                Text(TechniqueContent.summary(for: technique))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if locked {
                Image(systemName: "lock")
                    .foregroundStyle(Theme.inkSoft)
            } else {
                stageMark(for: technique)
            }
        }
    }

    @ViewBuilder
    private var practiceRow: some View {
        let available = FeatureGate.areDrillsAvailable(unlocked: entitlements.isUnlocked)
        if available {
            NavigationLink {
                PracticeMenuView()
            } label: {
                Label("Practice drills", systemImage: "repeat")
                    .foregroundStyle(Theme.ink)
            }
        } else {
            Button {
                paywall.present(.practiceDrills)
            } label: {
                HStack {
                    Label("Practice drills", systemImage: "repeat")
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "lock")
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }

    @ViewBuilder
    private func stageMark(for technique: Technique) -> some View {
        switch mastery.stage(for: technique) {
        case .learned:
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Theme.heri)
                .accessibilityLabel("Learned")
        case .practicing:
            Image(systemName: "circle.bottomhalf.filled")
                .foregroundStyle(Theme.inkSoft)
                .accessibilityLabel("Practicing")
        case .seen:
            Image(systemName: "eye")
                .foregroundStyle(Theme.inkSoft)
                .accessibilityLabel("Seen")
        case .unseen:
            EmptyView()
        }
    }
}

//
//  PracticeMenuView.swift
//  Shikaku
//
//  Drill list: each technique's board, run again without the lesson's
//  hand-holding. Mastery-locked rows are the ONE place .disabled is allowed
//  — they unlock by playing, not by paying, and the row says how.
//

import SwiftUI

struct PracticeMenuView: View {
    @Environment(MasteryTracker.self) private var mastery

    var body: some View {
        List {
            ForEach(Technique.allCases) { technique in
                row(for: technique)
            }
        }
        .navigationTitle("Practice")
        .scrollContentBackground(.hidden)
        .background(Theme.floor)
    }

    @ViewBuilder
    private func row(for technique: Technique) -> some View {
        let seen = mastery.stage(for: technique) > .unseen
        if seen {
            NavigationLink {
                LessonView(technique: technique)
            } label: {
                label(for: technique, hint: nil)
            }
        } else {
            label(for: technique, hint: "Take the lesson first")
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func label(for technique: Technique, hint: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(TechniqueContent.name(for: technique))
                .foregroundStyle(Theme.ink)
            Text(hint ?? TechniqueContent.summary(for: technique))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

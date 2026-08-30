//
//  DailyView.swift
//  Shikaku
//
//  The curriculum-tied daily: the card on Home, and the host that generates
//  today's board. Every player gets the same board, and the board is chosen
//  so today's named technique appears in its solve — the one daily in the
//  category that teaches instead of ranking.
//

import SwiftUI

/// The Home card. Free tier always — the daily's sizes are the free sizes by
/// design, so no gate ever touches this path.
struct DailyCard: View {
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var progress

    private var today: DayKey { DayKey(date: .now) }

    var body: some View {
        let day = today
        let done = progress.hasCompletedDaily(day)
        let streak = progress.displayStreak(today: day)
        Button {
            Haptics.previewTick()
            path.append(.daily(day))
        } label: {
            HStack(spacing: Layout.s4) {
                sealGlyph(done: done)
                VStack(alignment: .leading, spacing: Layout.s1) {
                    Text(done ? "Today's room is finished" : todaysLine)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(subtitle(done: done, day: day, streak: streak))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                if !done {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .padding(Layout.s4)
            .homeCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(done
            ? "Today's room is finished, streak \(streak)"
            : "\(todaysLine), streak \(streak)")
    }

    /// "Today needs Sole Owner" — the technique by name, which is the pitch.
    private var todaysLine: String {
        "Today needs \(TechniqueContent.name(for: DailySeed.spec(for: today).technique))"
    }

    private func subtitle(done: Bool, day: DayKey, streak: Int) -> String {
        if done, let seconds = progress.dailyTime(day) {
            return streak > 1
                ? "\(TimeFormatting.clock(seconds)) · streak \(streak)"
                : TimeFormatting.clock(seconds)
        }
        let plan = DailySeed.spec(for: day)
        return streak > 0
            ? "\(plan.size.label) · streak \(streak)"
            : plan.size.label
    }

    /// The day-seal: 今 ("now"). Vermilion only once today's room is done —
    /// the second permitted use of shu on this screen after the learned
    /// seals, and it is earned the same way.
    private func sealGlyph(done: Bool) -> some View {
        Text("今")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(done ? Theme.ink : Theme.inkSoft)
            .frame(width: 40, height: 40)
            .background(done ? AnyShapeStyle(Theme.shu) : AnyShapeStyle(Theme.frame))
            .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
    }
}

/// Generates today's board off-main behind the loading view, then hosts a
/// normal game marked as the daily.
struct DailyHostView: View {
    let day: DayKey

    @Environment(MasteryTracker.self) private var mastery
    @State private var game: ShikakuGame?

    var body: some View {
        Group {
            if let game {
                GameView(game: game)
            } else {
                PuzzleLoadingView()
            }
        }
        .task {
            guard game == nil else { return }
            let day = day
            let result = await Task.detached(priority: .userInitiated) {
                DailySeed.generate(for: day)
            }.value
            let plan = DailySeed.spec(for: day)
            let fresh = ShikakuGame(puzzle: result.puzzle, size: plan.size,
                                    difficulty: plan.difficulty, dailyDay: day)
            fresh.mastery = mastery
            game = fresh
        }
    }
}

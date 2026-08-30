//
//  WeekView.swift
//  Shikaku
//
//  This week's dailies: seven slots, Monday to Sunday. Finish all seven
//  and the week gets its seal. Missed days stay playable — the boards are
//  deterministic, so yesterday's room is still yesterday's room.
//

import SwiftUI

struct WeekView: View {
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var progress

    private var today: DayKey { DayKey(date: .now) }

    var body: some View {
        let days = ProgressStore.weekDays(containing: today)
        let sealed = progress.weeklySeals.contains(ProgressStore.weekKey(of: today))
        VStack(alignment: .leading, spacing: Layout.s2) {
            HStack {
                Text("This week")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                if sealed {
                    Text("週")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 22, height: 22)
                        .background(Theme.shu)
                        .accessibilityLabel("Week finished")
                }
            }
            HStack(spacing: Layout.s2) {
                ForEach(days, id: \.self) { day in
                    daySlot(day)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func daySlot(_ day: DayKey) -> some View {
        let done = progress.hasCompletedDaily(day)
        let isToday = day == today
        let isFuture = day > today
        Button {
            path.append(.daily(day))
        } label: {
            Text(dayLetter(day))
                .font(Theme.numberFont(size: 12))
                .foregroundStyle(done ? Theme.ink : (isFuture ? Theme.inkSoft.opacity(0.4) : Theme.inkSoft))
                .frame(width: 30, height: 30)
                .background(done ? AnyShapeStyle(Theme.mat) : AnyShapeStyle(Theme.frame))
                .overlay(Rectangle().strokeBorder(
                    isToday ? Theme.heri : Theme.hairline,
                    lineWidth: isToday ? 2 : 1))
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(slotLabel(day, done: done, isToday: isToday, isFuture: isFuture))
    }

    private func dayLetter(_ day: DayKey) -> String {
        ["S", "M", "T", "W", "T", "F", "S"][DailySeed.weekday(of: day) - 1]
    }

    private func slotLabel(_ day: DayKey, done: Bool, isToday: Bool, isFuture: Bool) -> String {
        let name = ["Sunday", "Monday", "Tuesday", "Wednesday",
                    "Thursday", "Friday", "Saturday"][DailySeed.weekday(of: day) - 1]
        if isFuture { return "\(name), not yet" }
        if done { return "\(name), finished" }
        return isToday ? "\(name), today's room" : "\(name), still open"
    }
}

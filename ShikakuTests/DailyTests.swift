import Foundation
import Testing
@testable import Shikaku

@Suite struct DailyTests {

    // MARK: - Seed & schedule

    @Test func seedIsDeterministicAndDayUnique() {
        let a = DayKey(year: 2026, month: 8, day: 30)
        let b = DayKey(year: 2026, month: 8, day: 31)
        #expect(DailySeed.seed(for: a) == DailySeed.seed(for: a))
        #expect(DailySeed.seed(for: a) != DailySeed.seed(for: b))
    }

    /// Zeller against a known anchor: 2026-08-30 is a Sunday.
    @Test func zellerWeekdayMatchesKnownDates() {
        #expect(DailySeed.weekday(of: DayKey(year: 2026, month: 8, day: 30)) == 1)
        #expect(DailySeed.weekday(of: DayKey(year: 2026, month: 8, day: 31)) == 2)
        #expect(DailySeed.weekday(of: DayKey(year: 2000, month: 1, day: 1)) == 7)
    }

    /// The schedule may never hand out a paywalled size (the daily is free by
    /// construction, not by exemption machinery) and never schedules the two
    /// techniques that cannot lead a generated board.
    @Test func scheduleStaysFreeAndGeneratable() {
        for offset in 0..<14 {
            let day = DayKey(date: Date(timeIntervalSince1970: 1_800_000_000
                                        + Double(offset) * 86_400))
            let plan = DailySeed.spec(for: day)
            #expect(FeatureGate.isBoardSizeAvailable(plan.size, unlocked: false))
            #expect(plan.technique != .oneCell)
            #expect(!Technique.allowedAbsentFromGeneratedPuzzles.contains(plan.technique))
        }
    }

    // MARK: - Streak

    private func freshStore() -> ProgressStore {
        let defaults = UserDefaults(suiteName: "daily-tests-\(UUID().uuidString)")!
        return ProgressStore(userDefaults: defaults)
    }

    @Test func consecutiveDaysGrowTheStreak() {
        let store = freshStore()
        let d1 = DayKey(year: 2026, month: 8, day: 29)
        let d2 = DayKey(year: 2026, month: 8, day: 30)
        store.recordDailyCompleted(day: d1, seconds: 100)
        store.recordDailyCompleted(day: d2, seconds: 90)
        #expect(store.displayStreak(today: d2) == 2)
        #expect(store.daily.bestStreak == 2)
    }

    @Test func aGapResetsTheDisplayedStreakWithoutErasingBest() {
        let store = freshStore()
        store.recordDailyCompleted(day: DayKey(year: 2026, month: 8, day: 25), seconds: 100)
        store.recordDailyCompleted(day: DayKey(year: 2026, month: 8, day: 26), seconds: 100)
        // Two days missed.
        let today = DayKey(year: 2026, month: 8, day: 29)
        #expect(store.displayStreak(today: today) == 0)
        #expect(store.daily.bestStreak == 2)
        store.recordDailyCompleted(day: today, seconds: 80)
        #expect(store.displayStreak(today: today) == 1)
    }

    @Test func recordingIsIdempotentPerDay() {
        let store = freshStore()
        let day = DayKey(year: 2026, month: 8, day: 30)
        store.recordDailyCompleted(day: day, seconds: 100)
        store.recordDailyCompleted(day: day, seconds: 50)
        #expect(store.dailyTime(day) == 100)
        #expect(store.daily.currentStreak == 1)
    }

    /// Replaying an older day must not rewind `lastCompleted` (the monotonic
    /// guard a sibling learned the hard way).
    @Test func replayingAnOlderDayCannotRewindTheChain() {
        let store = freshStore()
        let today = DayKey(year: 2026, month: 8, day: 30)
        store.recordDailyCompleted(day: today, seconds: 100)
        store.recordDailyCompleted(day: DayKey(year: 2026, month: 8, day: 20), seconds: 100)
        #expect(store.daily.lastCompleted == today)
    }
}

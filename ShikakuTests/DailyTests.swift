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

@Suite @MainActor struct MasteryWiringTests {

    /// The regression that made mastery dead code: the credit path must run
    /// from a real commit, advance to .learned after 5 unaided placements,
    /// and never fire for hint-applied ones.
    @Test func unaidedCommitsAdvanceMasteryAndHintedOnesDoNot() {
        let defaults = UserDefaults(suiteName: "mastery-tests-\(UUID().uuidString)")!
        let store = ProgressStore(userDefaults: defaults)
        let tracker = MasteryTracker(store: store)

        for round in 0..<6 {
            let lesson = TutorialPuzzles.lesson(for: .primeStrip)
            let game = ShikakuGame(puzzle: lesson.puzzle, size: .five,
                                   difficulty: .gentle, board: lesson.startingBoard)
            game.mastery = tracker
            // Drive the real input path: drag out the solver's own solution
            // for every clue, so each commit is correct and derivable.
            for (index, rect) in lesson.puzzle.solution.enumerated() {
                if round == 5 {
                    // The hinted round: applied placements must not credit.
                    game.applyHintPlacement(Placement(clueIndex: index, rect: rect))
                } else {
                    game.dragChanged(anchor: Cell(row: rect.minRow, col: rect.minCol),
                                     current: Cell(row: rect.maxRow, col: rect.maxCol))
                    game.dragEnded()
                }
            }
            #expect(game.didWin)
        }

        // Five clean boards of this two-clue puzzle = at least 5 unaided
        // credits on some technique; primeStrip's lesson credits primeStrip.
        #expect(tracker.stage(for: .primeStrip) == .learned)
        let before = store.mastery.perTechnique.values.reduce(0) { $0 + $1.unaided }
        // The all-hints round contributed nothing unaided.
        #expect(before <= 5 * TutorialPuzzles.lesson(for: .primeStrip).puzzle.clues.count)
    }
}

@Suite @MainActor struct ProofAndPathTests {

    /// A lesson advances the seal to .seen and leaves drill stats alone —
    /// the regression Kai saw as "the path doesn't show correctly".
    @Test func aFinishedLessonMarksSeenWithoutTouchingDrills() {
        let defaults = UserDefaults(suiteName: "proof-tests-\(UUID().uuidString)")!
        let store = ProgressStore(userDefaults: defaults)
        let tracker = MasteryTracker(store: store)
        tracker.recordLesson(technique: .oneCell)
        #expect(tracker.stage(for: .oneCell) == .seen)
        #expect(store.mastery.perTechnique[Technique.oneCell.rawValue]?.drilled == 0)
    }

    /// The grader: a hint-laid move is "shown", an unaided derivable move is
    /// "deduced", judged against the position it was played in.
    @Test func graderSeparatesShownFromDeduced() {
        let lesson = TutorialPuzzles.lesson(for: .primeStrip)
        let game = ShikakuGame(puzzle: lesson.puzzle, size: .five,
                               difficulty: .gentle, board: lesson.startingBoard)
        let solution = lesson.puzzle.solution
        // First clue by hint, the rest by hand.
        game.applyHintPlacement(Placement(clueIndex: 0, rect: solution[0]))
        for index in 1..<solution.count {
            let rect = solution[index]
            game.dragChanged(anchor: Cell(row: rect.minRow, col: rect.minCol),
                             current: Cell(row: rect.maxRow, col: rect.maxCol))
            game.dragEnded()
        }
        #expect(game.didWin)
        let graded = SolveGrader.grade(puzzle: lesson.puzzle, moves: game.history)
        #expect(graded.count == solution.count)
        #expect(graded.first?.verdict == .shown)
        let counts = SolveGrader.counts(graded)
        #expect(counts.shown == 1)
        #expect(counts.deduced + counts.leaps == solution.count - 1)
        #expect(counts.deduced >= 1)
    }

    /// generate(featuring:) really puts the technique in the trace.
    @Test func featuringGeneratorDeliversTheTechnique() {
        let outcome = ShikakuGenerator.generate(
            featuring: .onlyFit, size: .five, tier: .steady, seed: 424242)
        #expect(outcome.matched)
        #expect(outcome.result.trace.contains { $0.technique == .onlyFit })
    }
}

@Suite struct RoundSixTests {

    /// The miner's contract: from each position's placements alone, the
    /// first applicable technique is the target.
    @Test func minedPositionsPutTheTechniqueFirst() {
        let positions = LessonPositions.mine(technique: .soleOwner, count: 3, seed: 7)
        #expect(!positions.isEmpty)
        for position in positions {
            var state = SolverState(puzzle: position.puzzle)
            for p in position.preplaced { state.apply(placement: p) }
            let first = LogicalSolver.nextStep(puzzle: position.puzzle, state: state)
            #expect(first?.technique == .soleOwner)
            #expect(position.puzzle.solution.indices.contains(position.answerClue))
        }
    }

    /// Week math: seven days Monday–Sunday, stable key, seal awarding.
    @Test func weekSealAwardsOnlyWhenAllSevenAreDone() {
        let defaults = UserDefaults(suiteName: "week-tests-\(UUID().uuidString)")!
        let store = ProgressStore(userDefaults: defaults)
        let anchor = DayKey(year: 2026, month: 8, day: 26)   // a Wednesday
        let week = ProgressStore.weekDays(containing: anchor)
        #expect(week.count == 7)
        #expect(DailySeed.weekday(of: week[0]) == 2)          // Monday
        #expect(DailySeed.weekday(of: week[6]) == 1)          // Sunday
        for day in week.dropLast() {
            store.recordDailyCompleted(day: day, seconds: 60)
            store.awardWeekIfComplete(containing: day)
        }
        #expect(store.weeklySeals.isEmpty)
        store.recordDailyCompleted(day: week[6], seconds: 60)
        store.awardWeekIfComplete(containing: week[6])
        #expect(store.weeklySeals == [ProgressStore.weekKey(of: anchor)])
        // Idempotent.
        store.awardWeekIfComplete(containing: anchor)
        #expect(store.weeklySeals.count == 1)
    }

    /// Climb best is monotonic.
    @Test func climbBestOnlyRises() {
        let defaults = UserDefaults(suiteName: "climb-tests-\(UUID().uuidString)")!
        let store = ProgressStore(userDefaults: defaults)
        store.recordClimb(rooms: 5)
        store.recordClimb(rooms: 3)
        #expect(store.climbBest == 5)
    }
}

import Foundation
import Observation

/// A paused game, whole. `nonisolated`: it is pure Codable data built from
/// engine types, and it must be decodable wherever it is needed (the engine
/// side of a resume, tests) without hopping to the main actor.
///
/// `sizeRaw`/`difficultyRaw` rather than the enums, so a future enum case
/// change degrades to "couldn't resume" instead of "couldn't decode anything
/// stored under this key".
nonisolated struct GameSnapshot: Codable, Sendable, Equatable {
    var puzzle: Puzzle
    var board: BoardState
    var elapsedSeconds: Int
    var sizeRaw: Int
    var difficultyRaw: Int
    var hintsUsed: Int
}

/// Per-technique mastery counters. `unaided` only counts deductions made
/// without help — `creditedCells` survives undo, so place/undo/place is
/// indistinguishable from a fresh deduction (the anti-farming invariant).
nonisolated struct TechniqueMastery: Codable, Sendable, Equatable {
    var seen = 0
    var drilled = 0
    var unaided = 0
}

/// Mastery, keyed by `Technique.rawValue`. Tracking runs for free players too
/// — only the *display* is behind the unlock — so nothing is lost when they
/// buy.
nonisolated struct MasteryState: Codable, Sendable, Equatable {
    var perTechnique: [Int: TechniqueMastery] = [:]
}

/// All persisted progress: settings, best times, stats, mastery, and the
/// in-progress game. UserDefaults + Codable, versioned keys. No daily/streak
/// storage — Shikaku v1 ships without a daily puzzle.
@Observable @MainActor
final class ProgressStore {
    private let defaults: UserDefaults

    /// Every Codable domain gets its own key, deliberately: a schema break in
    /// one (say, `Stats` grows a field badly) throws away that one blob and
    /// leaves settings, best times, and the saved game standing. One combined
    /// blob would take them all down together.
    private enum Key {
        static let settings = "shikaku.settings.v1"
        static let saveGame = "shikaku.saveGame.v1"
        static let stats = "shikaku.stats.v1"
        static let bestTimes = "shikaku.bestTimes.v1"
        static let mastery = "shikaku.mastery.v1"
        static let lastPlayed = "shikaku.lastPlayed.v1"
        static let daily = "shikaku.daily.v1"
        static let hintTrend = "shikaku.hintTrend.v1"
        static let lastSolve = "shikaku.lastSolve.v1"
        static let climb = "shikaku.climb.v1"
        static let weeks = "shikaku.weeks.v1"
    }

    /// The size/difficulty the player last started a game with, so the pickers
    /// come back where they left them and the cache can warm the right key.
    struct GameChoice: Codable, Hashable {
        let size: BoardSize
        let difficulty: Difficulty
    }

    /// The player's most recent finished room, with every mat's commit
    /// order and provenance — the raw material of "the proof" replay.
    struct LastSolve: Codable, Equatable {
        var puzzle: Puzzle
        var moves: [ShikakuGame.SolveMove]
        var sizeRaw: Int
        var difficultyRaw: Int
        var seconds: Int
    }

    /// The daily-room record. `completedTimes` is keyed by `DayKey.isoString`
    /// so the JSON stays readable and time-zone-free. Ported from Hashi,
    /// including the monotonic guard on `lastCompleted`.
    struct DailyRecord: Codable, Equatable {
        var lastCompleted: DayKey?
        var currentStreak = 0
        var bestStreak = 0
        var completedTimes: [String: Int] = [:]
    }

    struct Settings: Codable, Equatable {
        var hapticsEnabled = true
        /// Whether committed-but-wrong rectangles get feedback. Wrong-area
        /// rectangles are allowed to commit at all because the free hint tier
        /// needs errors to exist — see docs/MONETIZATION.md.
        var errorFeedback = true
    }

    /// One (size, difficulty) slot. Raw values rather than the enums for the
    /// same schema-degradation reason as `GameSnapshot`.
    struct SolveKey: Hashable, Codable {
        let sizeRaw: Int
        let difficultyRaw: Int

        init(size: BoardSize, difficulty: Difficulty) {
            sizeRaw = size.rawValue
            difficultyRaw = difficulty.rawValue
        }
    }

    struct Stats: Codable, Equatable {
        var totalSolves = 0
        var totalHintsUsed = 0
        var solvesBySizeAndDifficulty: [SolveKey: Int] = [:]
        /// Hints taken in solved games, by `Difficulty.rawValue` — the
        /// hints-taken trend is the number that proves the app works.
        var hintsByDifficulty: [Int: Int] = [:]
    }

    /// Seconds, by (size, difficulty).
    private(set) var bestTimes: [SolveKey: Int] = [:]
    private(set) var stats = Stats()
    /// Mirrors the persisted save. Held as observable state rather than re-read
    /// on demand so the Continue card appears the moment a game is saved —
    /// reading UserDefaults inside a view body never invalidates it. This is
    /// the family invariant; do not turn it into a computed defaults read.
    private(set) var savedGame: GameSnapshot?
    private(set) var lastPlayed: GameChoice?
    private(set) var mastery = MasteryState()
    private(set) var daily = DailyRecord()
    /// Hints taken per solved room, most recent last, capped — the series
    /// behind Home's trend line. The one number that proves the app works:
    /// it should fall as the techniques land.
    private(set) var hintTrend: [Int] = []
    private(set) var lastSolve: LastSolve?
    /// Most rooms finished in one Climb run.
    private(set) var climbBest: Int = 0
    /// ISO-week keys ("2026-W35") for every calendar week whose seven
    /// dailies were all finished.
    private(set) var weeklySeals: [String] = []
    var settings = Settings() {
        didSet { save(settings, key: Key.settings) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        bestTimes = load([SolveKey: Int].self, key: Key.bestTimes) ?? [:]
        stats = load(Stats.self, key: Key.stats) ?? Stats()
        settings = load(Settings.self, key: Key.settings) ?? Settings()
        savedGame = load(GameSnapshot.self, key: Key.saveGame)
        lastPlayed = load(GameChoice.self, key: Key.lastPlayed)
        mastery = load(MasteryState.self, key: Key.mastery) ?? MasteryState()
        daily = load(DailyRecord.self, key: Key.daily) ?? DailyRecord()
        hintTrend = load([Int].self, key: Key.hintTrend) ?? []
        lastSolve = load(LastSolve.self, key: Key.lastSolve)
        climbBest = load(Int.self, key: Key.climb) ?? 0
        weeklySeals = load([String].self, key: Key.weeks) ?? []
    }

    func recordClimb(rooms: Int) {
        guard rooms > climbBest else { return }
        climbBest = rooms
        save(rooms, key: Key.climb)
    }

    /// Awards the weekly seal when all seven days of `week` are complete.
    /// Called after each daily win; idempotent.
    func awardWeekIfComplete(containing day: DayKey) {
        let week = Self.weekDays(containing: day)
        guard week.allSatisfy({ hasCompletedDaily($0) }) else { return }
        let key = Self.weekKey(of: day)
        guard !weeklySeals.contains(key) else { return }
        weeklySeals.append(key)
        save(weeklySeals, key: Key.weeks)
    }

    /// Monday through Sunday of the week containing `day` (Zeller weekday).
    nonisolated static func weekDays(containing day: DayKey) -> [DayKey] {
        // Walk back to Monday (weekday 2), then forward seven days.
        var start = day
        while DailySeed.weekday(of: start) != 2 { start = start.previous() }
        var days = [start]
        var cursor = start.date()
        for _ in 0..<6 {
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            days.append(DayKey(date: cursor))
        }
        return days
    }

    nonisolated static func weekKey(of day: DayKey) -> String {
        let monday = weekDays(containing: day)[0]
        return monday.isoString
    }

    func recordLastSolve(_ solve: LastSolve) {
        lastSolve = solve
        save(solve, key: Key.lastSolve)
    }

    // MARK: - Daily streak

    func hasCompletedDaily(_ day: DayKey) -> Bool {
        daily.completedTimes[day.isoString] != nil
    }

    func dailyTime(_ day: DayKey) -> Int? {
        daily.completedTimes[day.isoString]
    }

    /// The streak to *show*: 0 when the chain is already broken (yesterday
    /// missed), even before today is played. Computed, never stored —
    /// storage would go stale at midnight.
    func displayStreak(today: DayKey) -> Int {
        guard let last = daily.lastCompleted else { return 0 }
        if last == today || last == today.previous() { return daily.currentStreak }
        return 0
    }

    /// Records a completed daily. Idempotent per day; increments on
    /// consecutive days, resets to 1 otherwise. `lastCompleted` only moves
    /// forward — replaying an older day must not rewind the chain.
    func recordDailyCompleted(day: DayKey, seconds: Int) {
        guard !hasCompletedDaily(day) else { return }
        daily.completedTimes[day.isoString] = seconds
        if daily.lastCompleted == day.previous() {
            daily.currentStreak += 1
        } else {
            daily.currentStreak = 1
        }
        if daily.lastCompleted == nil || daily.lastCompleted! < day {
            daily.lastCompleted = day
        }
        daily.bestStreak = max(daily.bestStreak, daily.currentStreak)
        save(daily, key: Key.daily)
    }

    /// Records the *requested* size/difficulty for a new game.
    func recordLastPlayed(size: BoardSize, difficulty: Difficulty) {
        let choice = GameChoice(size: size, difficulty: difficulty)
        guard choice != lastPlayed else { return }
        lastPlayed = choice
        save(choice, key: Key.lastPlayed)
    }

    // MARK: - Best times / stats

    func bestTime(size: BoardSize, difficulty: Difficulty) -> Int? {
        bestTimes[SolveKey(size: size, difficulty: difficulty)]
    }

    /// Records a solve; returns true when it's a new best time.
    ///
    /// `isRecord` is computed BEFORE the table is updated. Re-deriving it
    /// after the update ("is my time the one in the table?") claims a record
    /// on an exact tie — equal times overwrite and then look like the best.
    @discardableResult
    func recordSolve(size: BoardSize, difficulty: Difficulty,
                     seconds: Int, hintsUsed: Int) -> Bool {
        let key = SolveKey(size: size, difficulty: difficulty)
        stats.totalSolves += 1
        stats.totalHintsUsed += hintsUsed
        stats.solvesBySizeAndDifficulty[key, default: 0] += 1
        stats.hintsByDifficulty[difficulty.rawValue, default: 0] += hintsUsed
        save(stats, key: Key.stats)

        hintTrend.append(hintsUsed)
        if hintTrend.count > 20 { hintTrend.removeFirst(hintTrend.count - 20) }
        save(hintTrend, key: Key.hintTrend)

        let isRecord = bestTimes[key].map { seconds < $0 } ?? true
        if isRecord {
            bestTimes[key] = seconds
            save(bestTimes, key: Key.bestTimes)
        }
        return isRecord
    }

    // MARK: - Save game

    /// Called on board change + scene backgrounding + disappear — never
    /// phase-change-only (the family invariant).
    func save(_ snapshot: GameSnapshot) {
        savedGame = snapshot
        save(snapshot, key: Key.saveGame)
    }

    func clearSavedGame() {
        savedGame = nil
        defaults.removeObject(forKey: Key.saveGame)
    }

    // MARK: - Mastery (used by MasteryTracker)

    /// Every mastery mutation goes through here so it cannot forget to
    /// persist, and `mastery` stays observable state with one writer.
    func updateMastery(_ mutate: (inout MasteryState) -> Void) {
        mutate(&mastery)
        save(mastery, key: Key.mastery)
    }

    // MARK: - Codable plumbing

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save(_ value: some Encodable, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}

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
    }

    /// The size/difficulty the player last started a game with, so the pickers
    /// come back where they left them and the cache can warm the right key.
    struct GameChoice: Codable, Hashable {
        let size: BoardSize
        let difficulty: Difficulty
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

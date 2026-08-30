import Foundation

/// A local-calendar day, the key for the daily room and its streak.
nonisolated struct DayKey: Hashable, Codable, Sendable, Comparable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year ?? 2000
        month = parts.month ?? 1
        day = parts.day ?? 1
    }

    var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    func previous(calendar: Calendar = .current) -> DayKey {
        let d = date(calendar: calendar)
        let prev = calendar.date(byAdding: .day, value: -1, to: d) ?? d
        return DayKey(date: prev, calendar: calendar)
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// The curriculum-tied daily: every player gets the same board, and each
/// day's board is generated to exercise a **named technique** — the thing no
/// other app in the category can offer, because no other app classifies
/// boards by reasoning.
///
/// **Never change the seed string or the schedule once shipped** — doing so
/// changes every future (and past) daily for everyone.
nonisolated enum DailySeed {

    /// FNV-1a over "shikaku.daily.v1.YYYY-MM-DD".
    static func seed(for day: DayKey) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in "shikaku.daily.v1.\(day.isoString)".utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    /// The week climbs the curriculum: easy arguments early, the one-ply
    /// techniques at the weekend. Sizes stay 5×5/7×7 — both free, so the
    /// daily needs no paywall exemption machinery at all.
    ///
    /// `oneCell` never leads (trivial) and `corridorCount` cannot (measured:
    /// zero appearances in generated traces; it is drill-only by design).
    static func spec(for day: DayKey) -> (technique: Technique, size: BoardSize, difficulty: Difficulty) {
        switch weekday(of: day) {
        case 2: (.primeStrip, .five, .gentle)      // Mon
        case 3: (.onlyFit, .five, .steady)         // Tue
        case 4: (.mustCover, .seven, .steady)      // Wed
        case 5: (.soleOwner, .seven, .sharp)       // Thu
        case 6: (.mustCover, .seven, .deep)        // Fri
        case 7: (.soleOwner, .seven, .severe)      // Sat
        default: (.strandedCell, .seven, .severe)  // Sun — the deep end
        }
    }

    /// 1 = Sunday … 7 = Saturday (Zeller's congruence — independent of
    /// Calendar and timezone, which already broke a sibling's streaks once).
    static func weekday(of day: DayKey) -> Int {
        var y = day.year
        var m = day.month
        if m < 3 {
            m += 12
            y -= 1
        }
        let k = y % 100
        let j = y / 100
        let h = (day.day + (13 * (m + 1)) / 5 + k + k / 4 + j / 4 + 5 * j) % 7
        // Zeller: 0 = Saturday … 6 = Friday → 1 = Sunday … 7 = Saturday.
        return ((h + 6) % 7) + 1
    }

    /// The day's board, and whether the scheduled technique really appears in
    /// its trace.
    struct DailyResult: Sendable {
        let puzzle: Puzzle
        let technique: Technique
        let techniqueMatched: Bool
    }

    /// Salted retry (round 0 unsalted, so a date that generates first try
    /// keeps its board forever): a seed whose board misses the scheduled
    /// technique retries deterministically, and every player self-heals to
    /// the same replacement. If no round matches, the last valid board ships
    /// with `techniqueMatched: false` — the card then speaks generically
    /// rather than naming a technique the board does not contain.
    static func generate(for day: DayKey, isCancelled: () -> Bool = { false }) -> DailyResult {
        let plan = spec(for: day)
        let base = seed(for: day)
        var fallback: Puzzle? = nil
        for round in 0..<10 {
            if isCancelled() { break }
            let salted = base &+ UInt64(round) &* 0x9E37_79B9_7F4A_7C15
            let result = ShikakuGenerator.generate(
                size: plan.size, tier: plan.difficulty, seed: salted,
                isCancelled: isCancelled)
            if result.trace.contains(where: { $0.technique == plan.technique }) {
                return DailyResult(puzzle: result.puzzle, technique: plan.technique,
                                   techniqueMatched: true)
            }
            if fallback == nil { fallback = result.puzzle }
        }
        // Deterministic last resort; same for everyone on that date.
        let puzzle = fallback ?? ShikakuGenerator.generate(
            size: plan.size, tier: plan.difficulty, seed: base,
            isCancelled: { false }).puzzle
        return DailyResult(puzzle: puzzle, technique: plan.technique, techniqueMatched: false)
    }
}

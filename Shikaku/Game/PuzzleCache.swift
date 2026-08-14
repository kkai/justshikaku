import Foundation
import Observation

/// Pre-generates the next puzzle per (size, tier) off the main actor so
/// starting a game rarely blocks on generation.
///
/// The table holds **tasks, not finished puzzles**. That is the whole design:
/// a request for a key that is already generating simply awaits that task, so
/// the failure mode this replaced in Kakuro — a cache miss starting a *second*
/// generation while the first was still running, and the player waiting on the
/// later one — cannot be expressed. There is one table, so there is nothing to
/// keep in sync. Nothing is persisted across launches: a cold launch just
/// warms again, and generation for the free sizes is fast enough that a
/// stale-board-versus-fresh-seed policy is not worth owning.
@Observable @MainActor
final class PuzzleCache {

    /// No daily case — Shikaku v1 ships without a daily puzzle.
    struct CacheKey: Hashable {
        let size: BoardSize
        let tier: Difficulty
    }

    /// A `final class` because identity matters: a late-finishing task must not
    /// clobber a fresher entry for the same key.
    private final class Entry {
        let task: Task<GenerationResult?, Never>
        var isClaimed = false

        init(task: Task<GenerationResult?, Never>) {
            self.task = task
        }
    }

    /// Not view state — nothing reads the table in a body, and marking it
    /// observed would invalidate views on every prefetch.
    @ObservationIgnored private var entries: [CacheKey: Entry] = [:]
    @ObservationIgnored private let generate:
        @Sendable (BoardSize, Difficulty, UInt64, () -> Bool) -> GenerationResult

    /// The `generate` seam mirrors `ProgressStore(userDefaults:)` — it makes
    /// the "did we generate once or twice?" question testable in milliseconds.
    init(generate: @escaping @Sendable (BoardSize, Difficulty, UInt64, () -> Bool)
         -> GenerationResult = { size, tier, seed, isCancelled in
             ShikakuGenerator.generate(size: size, tier: tier, seed: seed,
                                       isCancelled: isCancelled)
         }) {
        self.generate = generate
    }

    // MARK: - API

    /// Keeps a warm entry for this key, cancelling any other *running,
    /// unclaimed* generation. At most one speculative generation runs at a
    /// time — several concurrent ones would starve the cooperative pool and
    /// make the board the player is actually waiting for slower.
    func warm(size: BoardSize, tier: Difficulty) {
        let key = CacheKey(size: size, tier: tier)
        for (other, entry) in entries where other != key && !entry.isClaimed {
            entry.task.cancel()
            entries.removeValue(forKey: other)
        }
        guard entries[key] == nil else { return }
        entries[key] = makeEntry(key, priority: .utility)
    }

    /// Claims this key and awaits its result, starting a generation only if
    /// none is running. Awaiting a `.utility` warm task from a user-initiated
    /// context escalates its priority, so a half-done warm is finished, not
    /// duplicated. Returns `nil` only when the caller was cancelled (backed
    /// out before generation finished).
    func take(size: BoardSize, tier: Difficulty) async -> GenerationResult? {
        let key = CacheKey(size: size, tier: tier)
        let entry: Entry
        if let existing = entries[key] {
            entry = existing
        } else {
            entry = makeEntry(key, priority: .userInitiated)
            entries[key] = entry
        }
        entry.isClaimed = true

        // Bind the Sendable Task locally: `onCancel` is @Sendable and may run
        // off-main, so it must not capture MainActor-isolated state.
        let handle = entry.task
        let result = await withTaskCancellationHandler {
            await handle.value
        } onCancel: {
            handle.cancel()
        }
        settle(key, entry: entry, cancelled: result == nil)
        return result
    }

    /// Whether a generation for this key is running or already finished.
    /// Exists so tests can assert cache state directly.
    func isWarm(size: BoardSize, tier: Difficulty) -> Bool {
        entries[CacheKey(size: size, tier: tier)] != nil
    }

    // MARK: - Internals

    private func makeEntry(_ key: CacheKey, priority: TaskPriority) -> Entry {
        let generate = self.generate
        let seed = UInt64.random(in: .min ... .max)
        // Detached, so `Task.isCancelled` inside refers to the same task the
        // consumer cancels — no nesting, no second cancellation hop.
        let task = Task.detached(priority: priority) { () -> GenerationResult? in
            let result = generate(key.size, key.tier, seed, { Task.isCancelled })
            return Task.isCancelled ? nil : result
        }
        return Entry(task: task)
    }

    /// Retires a claimed entry once its consumer has the value.
    ///
    /// Identity-guarded: a task that finishes late must not remove an entry
    /// created after it.
    ///
    /// Dropping a **cancelled** entry is correctness, not tidiness — a
    /// cancelled task resolves to `nil` forever, so leaving it in the table
    /// would make every later request for that key hang on a value that never
    /// comes. Cancelled entries are dropped without re-warming; the player
    /// backed out, so speculatively rebuilding the board they abandoned is
    /// exactly the work we just cancelled.
    private func settle(_ key: CacheKey, entry: Entry, cancelled: Bool) {
        guard entries[key] === entry else { return }
        entries.removeValue(forKey: key)
        guard !cancelled else { return }
        warm(size: key.size, tier: key.tier)
    }
}

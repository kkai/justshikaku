# Monetization

**One non-consumable, one-time unlock — modelled directly on Just Kakuro.**
No subscription, no ads, no consumables. Port `kakuro`/`Hashi`'s `Store/`
rather than re-deriving it, including the comments.

| | |
|---|---|
| Product ID | `de.kaikunze.shikaku.full` |
| Type | Non-consumable |
| Price | $4.99 (family tier) |
| Family shareable | Yes |
| Display name | Shikaku Full |
| Description | "Every lesson, every drill, teaching hints, large grids and stats. One purchase, forever." |

Config at `StoreKit/Shikaku.storekit`, wired through the scheme. Keep it
**outside** the synchronized source root or it ships inside the app bundle.

## The free / paid line

Fresh app, no legacy users to protect — so the line is drawn purely on the
teaching argument: the free tier must let a player *fall in love with the
loop* (learn the rules, feel the hint engine catch a mistake, finish real
puzzles), and the purchase buys depth, not relief from sabotage.

**Free**
- The interactive rules tutorial, in full.
- Technique lessons for T1 (`oneCell`) and T2 (`primeStrip`).
- Grids **5×5 and 7×7**, every difficulty tier.
- **Errors-only hints** (`HintPolicy.errorsOnly`) — "something here is wrong"
  — enough to feel what the hint engine would do for you. This is why wrong-
  area rectangles are allowed to commit: the free hint tier needs errors to
  exist.
- Best times per (size, difficulty).

**Paid**
- Technique lessons T3–T7 and all practice drills.
- The full four-level hint ladder with the drawn argument.
- Grids **10×10 and 12×12**.
- Full stats: solve counts and history, hints-taken trend (the number that
  proves the app works), mastery path, per-technique detail.
- Mastery *display* — tracking keeps running for free players so nothing is
  lost when they buy.

**Difficulty is never gated.** A free player can play severe on 7×7 — gating
difficulty punishes the players most likely to buy (Kakuro's rule).

## Invariants (family-tested)

- All gating lives in `FeatureGate` as pure `nonisolated` functions taking
  `unlocked:` explicitly. `PaidFeature` cases: `.largerBoards`, `.lessons`,
  `.practiceDrills`, `.teachingHints`, `.fullStats`.
- **No gated control is ever `.disabled()`.** Locked rows stay tappable and
  present the paywall, and say what unlocks them.
- **Restore lives in Settings, unconditionally** — not only inside the
  paywall sheet.
- `EntitlementSource.isOwned` returns `Bool?`; `nil` (couldn't determine)
  never downgrades a cached entitlement — the error path protects offline
  players. `Transaction.updates` listener starts in `EntitlementStore.init`.
- A withheld hint never calls `recordHint`.
- Tests: `EntitlementTests` asserts the free set **exactly**; a source scan
  asserts every `PaidFeature` has a `paywall.present(.case)` somewhere
  (Numeriqo shipped a feature advertised on the paywall and sold from
  nowhere).

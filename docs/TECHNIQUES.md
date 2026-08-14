# The technique ladder

Seven techniques, in teaching order. **The `Technique` enum's declaration order
is the source of truth** for five consumers: the solver loop (lowest-tier
applicable technique first, never first-found), difficulty weights, hint
escalation, the tutorial sequence, and the practice menu. Change the order in
one place only.

The engine's foundation is **candidate enumeration**: a candidate for clue *i*
is a rectangle with area = value, inside the grid, containing clue *i* and no
other clue. For value v: enumerate divisor pairs (w,h), slide the w×h window
over every offset containing the clue cell, clip to bounds, reject multi-clue
rects. Enumerated once per puzzle in deterministic order (shape, then
position); candidate lists only ever shrink. Differentially tested against
brute force — this is the correctness lynchpin; being wrong here corrupts
difficulty, hints, and generation at once.

Per-cell reachability is a `ClueMask` (two `UInt64` words, ≤128 clues; a 12×12
board tops out near 40). It powers T4–T6 without allocation.

## T1 `oneCell` — "Ones"

A clue of value 1 is its own rectangle. Detector: `value == 1 && !placed`.
The freebie tier. Generation caps these per difficulty; deep/severe boards
have zero.

## T2 `primeStrip` — "Prime Strips"

A prime clue can only be a 1×n strip. When exactly one strip fits, place it.
Detector: value is prime and `candidates.count == 1`. Machine-subsumed by T3,
kept as its own case so the *simpler argument* ("7 is prime, so it's a strip —
and only one strip fits") gets its own lesson, prose, and mastery slot; ordered
before T3 so the solver prefers the cheaper explanation (the family's
divisibility-before-combinations precedent).

## T3 `onlyFit` — "Only Fit"

A clue with exactly one live candidate: place it. Detector:
`candidates.count == 1`. Early instances come from geometry alone (walls,
neighbouring clues); late instances are the payoff of prior eliminations —
Shikaku's naked single.

## T4 `mustCover` — "Common Ground"

Cells contained in **every** live candidate of a clue belong to that clue,
even before its rectangle is known. Claim them; eliminate every other clue's
candidates passing through them. Detector: intersect the candidate rects
(interval min/max, O(candidates)); fires when the claim kills a foreign
candidate or adds a new visible claim mark.

## T5 `soleOwner` — "Lone Reacher"

An uncovered cell reachable by exactly one clue must belong to it; eliminate
that clue's candidates that do *not* cover the cell. Detector: per-cell
`ClueMask`, popcount 1, non-empty elimination. (Popcount 0 is a contradiction
and cannot occur in shipped puzzles.) If the clue collapses to one candidate,
T3 places it on the next pass.

## T6 `strandedCell` — "No Orphans"

One-ply lookahead: hypothetically commit candidate R; if some uncovered cell
would then have zero reachers, eliminate R. Detector: per candidate, recompute
reach near R; short-circuit on the first stranded cell. The corridor /
bottleneck argument in its cheap form.

## T7 `corridorCount` — "Count the Room"

The counting form. For a connected uncovered region, each reaching clue can
contribute at most `max over its candidates of |candidate ∩ region|` cells. If
the maxima sum to less than the region's area, the position is contradictory —
run one-ply after hypothetically committing candidate c to eliminate c.
Detector: flood-fill regions, interval intersections, integer sums.
("Even the biggest fits leave this corridor two short.")

## Excluded from v1

Checkerboard/parity counting. Numeriqo measured its parity technique at **zero
appearances in 1,200 generated boards** — a cheaper detector always arrives
first — and the same dynamic is near-certain here.

## Expect the tail to be unreachable

Plan from day one for T7 (and possibly T6) to be rare-or-absent in generated
solver traces, for the same reason parity was. Port the
`Technique.unreachableInGeneratedPuzzles` mechanism, pin the measurement **both
ways** in the EngineCheck harness (if the assumption changes, a test says so),
and hand-author drill boards for T6/T7 — kakuro precedent: three of its eight
techniques are drill-only.

## Difficulty

Tiers **gentle / steady / sharp / deep / severe**, graded by the hardest
technique in the `LogicalSolver` trace plus weighted counts:
gentle = T1–T3 from initial candidates; steady adds T4; sharp adds T5;
deep adds T6; severe requires T7 or dense T6 chains. Thresholds live in
`DifficultyRater.thresholds` and are recalibrated with
`SHIKAKU_CALIBRATE=1 /tmp/enginecheck` whenever generation, the technique set,
or the weights change — the numbers are meaningless otherwise.

Mastery credits the **hardest-weighted link in the elimination chain** behind a
placement, ranked by `DifficultyRater.weight`, not curriculum position — T3 is
taught early but trivial; the elimination work that earned the placement is
what deserves credit.

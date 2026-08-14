# Architecture

**Just Shikaku follows the family structure** (kakuro → Hashi → numeriqo_new).
Those are shipping, tested implementations of this exact product shape —
human-technique solver, teaching hint engine, practice drills, mastery
tracking, one-time unlock. Their `docs/ENGINEERING.md` files record mistakes
already paid for. **Read `../numeriqo_new/docs/ENGINEERING.md` and
`../kakuro/docs/ENGINEERING.md` before starting.** Deviate only where Shikaku
genuinely differs.

## 1. Project shape

A single Xcode project, `objectVersion 77` with
`PBXFileSystemSynchronizedRootGroup` — new Swift files under `Shikaku/` and
`ShikakuTests/` join the build automatically; **never edit `project.pbxproj`
to add files**.

```
Shikaku/
├── Shikaku.xcodeproj
├── Shikaku/
│   ├── App/            # @main, ContentView, Route enum navigation, Home/Stats/Settings
│   ├── Engine/         # pure logic. No SwiftUI. All `nonisolated` + Sendable.
│   ├── Game/           # play screen, board rendering, drag gesture, puzzle cache
│   ├── Teaching/       # lessons, hint engine, drills, mastery
│   ├── Design/         # Theme, Motion, Haptics, Layout
│   ├── Persistence/    # ProgressStore
│   └── Store/          # the one-time unlock
├── ShikakuTests/
├── ShikakuUITests/
├── Tools/EngineCheck/  # CLI harness — OUTSIDE Shikaku/ (top-level code can't be in an app target)
├── StoreKit/Shikaku.storekit   # OUTSIDE Shikaku/ or it ships in the bundle
└── docs/
```

iPhone-only v1 (`TARGETED_DEVICE_FAMILY = 1`), iOS 18.5, Swift 6,
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (engine types explicitly
`nonisolated` so generation runs off-main). One SKU — **no Pro variant
target**, so no ProBuildTests analogue; if one is ever added, use Numeriqo's
same-synchronized-group + scheme-level `<SkippedTests>` pattern.

Conventions: Model-View, no ViewModels, `@Observable` (never
ObservableObject), `@Environment` for services, view state as enums,
`.task(id:)`, `struct` over `class`, classes `final`, no force unwraps,
Swift Testing.

## 2. Engine data model

```swift
nonisolated struct Cell: Hashable, Codable, Sendable, Comparable { let row, col: Int }

/// Closed cell range, inclusive on both ends.
nonisolated struct GridRect: Hashable, Codable, Sendable {
    let minRow, minCol, maxRow, maxCol: Int
    // derived: width, height, area, contains(_:), overlaps(_:), cells (row-major)
}

nonisolated struct Clue: Codable, Sendable, Equatable { let cell: Cell; let value: Int }

nonisolated struct Puzzle: Codable, Sendable {
    let size: Int              // square boards in v1
    let clues: [Clue]          // index is the clue's identity everywhere
    let solution: [GridRect]   // solution[i] is clue i's rectangle
}

nonisolated struct PlacedRect: Codable, Sendable, Equatable {
    var rect: GridRect
    var clueIndex: Int         // gesture layer guarantees exactly one clue inside
}

nonisolated struct BoardState: Codable, Sendable {
    var placed: [PlacedRect]
    var claims: [Cell: Int]    // hint-applied "cell belongs to clue k" marks
}
```

`claims` is Shikaku's pencil-mark analogue: it makes elimination-only hint
steps *visibly* apply (the family invariant that Apply must do something the
player can see), and it survives undo like any board change.

Candidate enumeration and the `ClueMask` bitset: see `TECHNIQUES.md`.

## 3. Solvers

Two, with strictly separate jobs — the family split:

- **`LogicalSolver`** — the human-technique solver. `nextStep(puzzle:state:)`
  powers hints. Applies the **lowest-tier applicable technique**, never the
  first found, or difficulty inflates. Emits structured `ExplanationData`
  (clue indices, candidate rects, eliminated rects, claimed cells, region,
  area numbers) — never a string.
- **`BacktrackingSolver`** — `countSolutions(limit: 2)`, uniqueness proof
  only, never a hint source. Order clues by ascending live-candidate count,
  commit, prune overlaps, recurse. Hot path allocation-free — kakuro measured
  arrays/filter/reduce there at ~7µs/node vs ~1µs.

## 4. Generation

**Invariant: every shipped puzzle is provably unique AND fully solvable by
`LogicalSolver`.** Enforced at `generate()`'s single exit. This is what makes
the hint guarantee real.

`ShikakuGenerator.generate(matching:size:seed:)` — graded, returns the nearest
band rather than refusing (wire the grade to the picker from day one; the
family shipped a build where grading existed but wasn't wired, making tiers
meaningless).

1. **Seeded RNG** — `SeededRandomNumberGenerator` ported unchanged;
   known-seed → known-board pinned by test.
2. **Partition** by scanline packing, not guillotine: repeatedly take the
   topmost-leftmost uncovered cell, choose a random (w,h) from the tier's size
   distribution that fits anchored there; 1×1 fallback guarantees termination.
   Reading-order seeding is deliberate — random seeding fragments free space
   and strands unwanted freebies (Numeriqo measured 21–24% vs a requested 6%).
   Bias the size distribution upward (large pieces fail to fit, the result
   skews smaller). Reject partitions violating tier quality bars: 1×1 cap
   (zero on deep/severe), 1×2 cap, mean-area floor — all in the **same unit**
   (share of cells); the family paid once for mixing units.
3. **Clue placement inside each rectangle — the main difficulty lever.** The
   initial candidate count for a prospective clue cell is exact and cheap:
   per tier, pick the cell minimising it (gentle — corners, hugging walls),
   randomly (steady), or maximising it (deep/severe — central, symmetric
   ambiguity).
4. **Uniqueness** via `countSolutions(limit: 2)`. On failure re-roll clue
   placements first (cheap, usually restores uniqueness), then re-partition;
   discard-and-retry over structural repair until 75% of budget spent.
5. **Solvability gate**: `LogicalSolver.solve` with the tier's technique
   ceiling; reject anything unfinished. Expect Numeriqo's result to repeat:
   a stronger curriculum makes generation *faster* (the gate rejects less).
6. **Grade** from the trace; return in-band or nearest.

**Deterministic node budget** over the whole call (backtracker nodes + solver
steps + attempts — never wall-clock), `Task.isCancelled` at every budget
checkpoint, **baked fallback puzzles** (three per size×tier, stored as
literals, re-proven unique and solvable by a harness test) on exhaustion.

`PuzzleCache` ports from Hashi: warm the next puzzle for the current
(size, tier) while the player solves; persist the warm puzzle across launches.
Shikaku generation is far cheaper than Calcudoku's (no Latin square, tiny
candidate sets) — but keep the loading screen and measure 12×12 severe in
Release before assuming.

## 5. Gesture model (Shikaku's NumberPad analogue)

One `DragGesture(minimumDistance: 0)` on the board layer; state lives in
`ShikakuGame`, geometry in `BoardGeometry.cell(at:)`.

- **onChanged**: first change sets `dragAnchor = cell(at: start)`; each change
  sets `dragCurrent` (clamped to the board — dragging off-edge pins to the
  border, never cancels). `previewRect` = bounding box anchor…current.
  Preview renders live: ghost outline + translucent fill + an **area badge**
  `count/need` once the preview contains exactly one clue, tinted valid at
  equality. Haptic tick when the preview grows/shrinks by a cell.
- **onEnded, anchor == current (tap)**: inside a committed rect → delete it.
  Elsewhere → no-op. No selection state exists, so Kakuro's
  tap-toggles-selection trap cannot arise.
- **onEnded, real drag (commit)**:
  - exactly one clue inside → commit `PlacedRect`; previously committed rects
    it overlaps are **removed first** (redraw-over is the standard fluid
    Shikaku interaction and doubles as resize). Wrong area **is allowed to
    commit** and displays as a conflict (red `have/need` badge) — the error
    hint tier needs something to point at, and the free tier's errors-only
    hints would otherwise have no subject.
  - zero or 2+ clues inside → reject: shake the preview, warning haptic,
    nothing commits. Such rects are never meaningful.
- Tap on a clue with exactly one remaining candidate → auto-place (the
  remove-busywork move).
- Undo/redo: op stack of place/remove mutations; mastery credit state
  survives undo (anti-farming).

Errors follow the family rule — **compare against the solution, not the
rules**: a rect can satisfy every local rule and still be wrong. Rule-level
conflicts (wrong area) always show via the badge regardless of the
error-feedback setting.

## 6. Rendering

`BoardGeometry` ports nearly unchanged from numeriqo_new (drop the clue
gutter — Shikaku clues are single centred numerals; keep floored cell size,
centred origin, `cell(at:)`, type sizes derived from cellSize). One
absolutely-positioned layer against it: hairline grid → committed fills →
outlines → clue numerals → drag preview → argument overlay.

Two outline shapes:
- **`RectOutline`** (new, small) — placed/preview rectangles; inset rect with
  `animatableData`. CageOutline's boundary walk is overkill for axis-aligned
  rects.
- **`RegionOutline`** — port CageOutline's half-edge walk (renamed) for
  outlining **non-rectangular uncovered regions** in T6/T7 arguments. Keep all
  four hard-won fixes: lexicographic deterministic start vertex,
  geometry-derived pitch, single-subpath assertion, `animatableData`.

Pre-split `BoardView` and the preview into small `@ViewBuilder` pieces with
explicitly-typed intermediates from the start — three sibling views hit
"unable to type-check this expression in reasonable time"; don't re-earn it.

## 7. Teaching

Mirrors the family file-for-file: `HintEngine` (nudge → technique → highlight
→ resolution; errors beat teaching; locked hints never `recordHint`;
`focusCells` empty below `.highlight`), `ArgumentOverlay` (rectangle
vocabulary — see `TEACHING.md`), `TutorialScript` DSL + hand-authored
`TutorialPuzzles`, `PracticeDrills` with
`bakedBoardsThatDemonstrateTheirTechnique`, `MasteryTracker`,
`TechniqueContent` (the only file where `ExplanationData` becomes English).

**Bake the early curriculum**: assume from the start that early lessons need
hand-authored boards (a cheaper detector reaches those positions first in
generated traces), pinned by a `TutorialFixtureTests` analogue.

## 8. Persistence

`ProgressStore`, `@Observable @MainActor`, UserDefaults + Codable, versioned
keys (`shikaku.*.v1`), `init(userDefaults:)` seam. Save on board change +
scene backgrounding + disappear (phase-change-only saving loses everything);
`savedGame` is observable state, never a defaults read in a view body;
`ResumeGameView` resolves the snapshot once on appear; `recordSolve` returns
whether it was a record (re-deriving claims a record on an exact tie).

## 9. Testing

- Per-technique fixtures: boards where the technique **must** fire, and
  near-misses where it **must not** — a spurious hint teaches something false.
- Differential candidate enumeration vs brute force (§2, non-negotiable).
- Property tests: every generated puzzle unique, solvable, tier matching
  trace; seed reproducibility; budget determinism.
- `EntitlementTests` asserting the free set exactly; the source scan proving
  every `PaidFeature` has a `paywall.present` somewhere.
- `ThemeIsolationTests` ported verbatim, before any Design code exists.
- `GestureModelTests` (new): anchor/preview/commit/reject/tap-delete/
  redraw-over as pure functions on `ShikakuGame`.

Two verification paths, both required (the harness compiles without MainActor
default isolation and cannot see the app target's concurrency errors):

```bash
swiftc -O -o /tmp/enginecheck Shikaku/Engine/*.swift Tools/EngineCheck/*.swift && /tmp/enginecheck
xcodebuild test -project Shikaku.xcodeproj -scheme Shikaku \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'
```

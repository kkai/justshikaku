# Engineering notes

Working notes: invariants and things that have already gone wrong once —
here or in a sibling. Inherits `../../numeriqo/docs/ENGINEERING.md` and
`../../kakuro/docs/ENGINEERING.md`; the sections below repeat only what is
load-bearing or Shikaku-specific.

## Build & test

Two independent verification paths. **Both must pass.**

```bash
# 1. Engine harness — pure Swift, no simulator, seconds.
swiftc -O -o /tmp/enginecheck Shikaku/Engine/*.swift Tools/EngineCheck/*.swift
/tmp/enginecheck; echo "exit=$?"

# 2. App + play layer.
xcodebuild -project Shikaku.xcodeproj -scheme Shikaku \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build
xcodebuild test -project Shikaku.xcodeproj -scheme Shikaku \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'
```

**Always pin `OS=`.** This machine has many iOS runtimes and an unpinned
device name matches several. iPhone 15 Pro's local runtime is iOS 17.0 —
below our floor; use iPhone 16 Pro at 18.5. If simulator cloning fails
("stuck in creation state"): `-destination 'id=<udid>' -parallel-testing-enabled NO`.

Resolve a built `.app` with `-showBuildSettings BUILT_PRODUCTS_DIR`, never
`find` — the family has installed a stale sibling `.app` that way.

Difficulty recalibration: `SHIKAKU_CALIBRATE=1 /tmp/enginecheck` prints the
threshold table to paste into `DifficultyRater.thresholds`. Re-run whenever
generation, the technique set, or the weights change.

### Why two suites

The harness compiles **without** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
so it cannot see the concurrency errors the app target sees (Numeriqo's first
xcodebuild of a fully green engine surfaced two real ones — a mutable static
and a MainActor-isolated extension the nonisolated solver couldn't call).
Engine **extensions** need `nonisolated` too, not just types.

## Project

`objectVersion 77`, `PBXFileSystemSynchronizedRootGroup` — files under
`Shikaku/` and `ShikakuTests/` join the build automatically; **never edit
`project.pbxproj` to add files**. `Tools/`, `docs/`, `StoreKit/`, `AppStore/`
sit **outside** `Shikaku/` deliberately: the synchronized group would ship
them inside the app bundle, and `Tools/EngineCheck/main.swift` holds
top-level code that cannot be in an app target at all.

## Actor isolation in `Design/`

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` makes every unannotated type
`@MainActor` — including closures handed to UIKit.

- `Theme` and `Motion` are **`nonisolated`** — load-bearing.
  `UIColor.init(dynamicProvider:)` is imported without `NS_SWIFT_SENDABLE`;
  a closure literal inheriting MainActor gets an executor assertion that
  UIKit's `com.apple.SwiftUI.AsyncRenderer` thread trips —
  **EXC_BREAKPOINT, intermittent, anywhere, including idle on Home.** It
  shipped in Just Kakuro.
- `ThemeRGBA` holds plain components so the provider closure captures only
  `Sendable` values; the closure is *also* explicitly `@Sendable`
  (belt-and-braces: either annotation alone prevents the trap).
- `Haptics` is `@MainActor` and must stay so.
- Guarded three ways by `ThemeIsolationTests` (compile-time, runtime off-main
  resolve of every token, source scan for dynamic providers outside
  Theme.swift). Ported before any Design code was written. Do not "fix".

## SwiftUI type-checker budget

Sibling views failed with "unable to type-check this expression in reasonable
time" three separate times (outline arithmetic, cell placement, cell body).
`BoardView`, the drag preview, and `ArgumentOverlay` are split into small
`@ViewBuilder` pieces with explicitly-typed intermediates **from the start**
and say so in comments. Do not re-inline.

## Board layout

One absolutely-positioned layer; `BoardGeometry` is the single source of
truth for every cell rect — cells, hairlines, outlines, numerals, preview,
and the drawn argument all position against it. Cell size **floored to a
whole point** (fractional sizes seam at some scales and read as a rendering
bug). Font sizes derive from cellSize.

## Engine determinism

- No `Dictionary` iteration or `.first(where:)` anywhere order matters —
  candidate lists, region walks, and outline seeds use deterministic order
  (the family's animated stroke used to start at a random corner per launch).
- Generation bounded by a **deterministic node budget**, never wall-clock and
  never attempt counts alone; `Task.isCancelled` at budget checkpoints; baked
  fallbacks on exhaustion, re-proven by a harness test.
- `SeededRandomNumberGenerator` pinned by known-seed → known-board tests.

## Play layer invariants

- Wrong-area rects **commit and display as conflicts** (red `have/need`
  badge); zero/2+-clue rects never commit. Rationale in ARCHITECTURE.md §5 —
  the free tier's errors-only hints need errors to exist.
- Errors compare against **the solution, not the rules** — a locally-legal
  rect can still be wrong, and those are the mistakes that let a player drift
  twenty moves.
- Apply must visibly do something: elimination-only steps materialise claim
  marks via `applyStep`.
- Tap does **not** toggle selection (there is no selection state) — a UI
  driver re-tapping must never look like ignored input.
- `creditedClues` survives undo (anti-farming).

## Persistence

- Save on board change + scene backgrounding + disappear — never
  phase-change-only (a game started and never paused never changes phase).
- `savedGame` is observable state, not a defaults read in a view body.
- `ResumeGameView` resolves the snapshot once, on appear (winning clears the
  save and would otherwise swap the game out mid-celebration).
- `recordSolve` returns whether it was a record.

## Store

- `isOwned: Bool?` — `nil` never downgrades.
- No gated control `.disabled()`; Restore in Settings unconditionally;
  every `PaidFeature` has a `paywall.present` (source-scan test).

## Accessibility

`ShikakuUITests` runs `performAccessibilityAudit()` per screen, launched with
`-uiTestResetState` (DEBUG-guarded in the app; audits inherit prior state
otherwise and time out on stray alerts). One audit per state;
`XCTExpectFailure` scope as small as the thing it excuses (it absorbs every
failure in its test, and swallowed a real bug once). Board digits sized to
cells are an expected Dynamic Type failure — do not widen filters to hide it.
Hint text and wins announce via `AccessibilityNotification.Announcement`;
cells expose a custom action naming which mat they belong to (what the
outline conveys and speech cannot).

## Driving the simulator

fb-idb from **a single Python process** (chained `idb ui tap` in a shell loop
drops taps): `/Users/kai/work/areas/ios/studio/idb-venv/bin/idb`. Check liveness
separately (`xcrun simctl spawn <udid> launchctl list | grep -i shikaku`) — a
dropped tap and a dead app look identical. Coordinates are points; iPhone 16
Pro is 402×874 @3x.

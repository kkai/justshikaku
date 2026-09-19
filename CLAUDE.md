# CLAUDE.md — Just Shikaku

iPhone puzzle game (iOS 18.5+) teaching Shikaku (rectangle partition), modeled on Good Sudoku. Clone #4 of the family `../kakuro` → `../hashi` → `../numeriqo` — same architecture, same invariants. Deep engineering notes: `docs/ENGINEERING.md` (and `../numeriqo/docs/ENGINEERING.md` + `../kakuro/docs/ENGINEERING.md` for the lessons this project inherits).

## Critical invariants

- **Never edit project.pbxproj to add files.** `objectVersion 77` + `PBXFileSystemSynchronizedRootGroup`: every `.swift` file under `Shikaku/` and `ShikakuTests/` joins the build automatically.
- **`Shikaku/Engine/` is pure**: no SwiftUI/UIKit imports, every type `nonisolated` + `Sendable`. It must compile as a CLI: `swiftc -O -o /tmp/enginecheck Shikaku/Engine/*.swift Tools/EngineCheck/*.swift` (harness output to stderr).
- **`Theme` and `Motion` are `nonisolated` — load-bearing.** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` project-wide; a `UIColor(dynamicProvider:)` closure that inherits MainActor traps off-main (`EXC_BREAKPOINT`, intermittent, shipped in kakuro once). Guarded by `ThemeIsolationTests`; do not "fix".
- **No ViewModels.** `@Observable` (never ObservableObject), `@Environment` for services, view state as enums, `.task(id:)` for async effects.
- Every shipped puzzle is unique-solution AND fully solvable by `LogicalSolver` — enforced inside `ShikakuGenerator.generate`, not by convention. Deterministic node budget, seeded RNG, baked fallbacks.
- `LogicalSolver` applies the **lowest-tier applicable technique**; `BacktrackingSolver` is uniqueness proof only, never a hint source, hot path allocation-free.
- **All paid-tier gating lives in `FeatureGate`**, as pure `nonisolated` functions taking `unlocked:` explicitly. Never scatter `isUnlocked` through views.
- `EntitlementSource.isOwned` returns `Bool?` — `nil` means "couldn't determine" and **must never downgrade** a cached entitlement. The `Transaction.updates` listener starts in `EntitlementStore.init`, not a view's `.task`.
- Paywalled rows stay **tappable** (they present the paywall); only mastery-locked rows are `.disabled`. No gated control is ever `.disabled()`.
- `Technique` enum declaration order is the source of truth for the solver loop, difficulty weights, hint escalation, tutorial sequence, and practice menu.
- Persistence: save on board change + scene backgrounding + disappear (never phase-change-only); `savedGame` is observable state, not a defaults read in a view body.
- Anti-farming: `creditedCells` survives undo (place/undo/place is indistinguishable from a fresh deduction).
- The engine never holds a string: `LogicalSolver` emits structured `ExplanationData`; `TechniqueContent.swift` is the only place it becomes English.

## Build & test

```bash
# Fast engine iteration — no simulator, seconds:
swiftc -O -o /tmp/enginecheck Shikaku/Engine/*.swift Tools/EngineCheck/*.swift && /tmp/enginecheck
SHIKAKU_CALIBRATE=1 /tmp/enginecheck     # difficulty threshold table for DifficultyRater

# App + tests (ALWAYS pin OS= — this machine has many runtimes):
xcodebuild -project Shikaku.xcodeproj -scheme Shikaku -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build
xcodebuild test -project Shikaku.xcodeproj -scheme Shikaku -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'
```

Both suites are required: the harness compiles without `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so it cannot see the app target's concurrency errors. If simulator cloning fails ("stuck in creation state"): `-destination 'id=<udid>' -parallel-testing-enabled NO`. Resolve a built `.app` via `-showBuildSettings BUILT_PRODUCTS_DIR`, never `find`.

## Layout

- `Shikaku/App/` — @main, ContentView, `Route` navigation, HomeView, StatsView, SettingsView
- `Shikaku/Engine/` — Models, candidate enumeration, LogicalSolver (powers hints), BacktrackingSolver (uniqueness only), ShikakuGenerator, Difficulty, SeededRandomNumberGenerator
- `Shikaku/Game/` — ShikakuGame (@Observable @MainActor service, not a ViewModel), BoardView/BoardGeometry/RectGesture, MatOutline, PuzzleCache
- `Shikaku/Teaching/` — HintEngine (nudge → technique → highlight → resolution), ArgumentOverlay, tutorial DSL + baked lesson boards, PracticeDrills, MasteryTracker, TechniqueContent (all prose)
- `Shikaku/Design/` — Theme ("tatami room" palette), Motion (named tokens only — no inline animation values in views), Haptics
- `Shikaku/Persistence/` — ProgressStore (UserDefaults + Codable, versioned keys `shikaku.*.v1`, `init(userDefaults:)` test seam)
- `Shikaku/Store/` — one-time unlock: FeatureGate, EntitlementStore, PaywallPresenter + PaywallView + LockedFeaturePanel
- `Tools/EngineCheck/`, `StoreKit/Shikaku.storekit`, `docs/` — repo root, **outside `Shikaku/`**, because the synchronized root group ships anything under it inside the app bundle

## Conventions

Swift 6, Swift Testing (`@Suite`/`@Test`/`#expect`) in `ShikakuTests` hosted by the app. `struct` over `class`, classes `final`, no force unwraps. Team `8H42EZRCCP`, bundle `de.kaikunze.shikaku`, display name "Just Shikaku".
